defmodule EdgeDB.Client do
  @moduledoc false

  import EdgeDB.Protocol.Types

  require Logger

  @proto_ver_major 0
  @proto_ver_minor 7

  @msg_tag_authentication 0x52

  def connect(opts \\ []) do
    hostname = opts |> Keyword.get(:hostname, "localhost") |> String.to_charlist()
    port = Keyword.get(opts, :port, 5656)
    username = Keyword.fetch!(opts, :username)
    password = Keyword.get(opts, :password)
    database = Keyword.fetch!(opts, :database)

    connect_timeout = Keyword.get(opts, :connect_timeout, 5000)

    enforced_opts = [packet: :raw, mode: :binary, active: false]
    # :gen_tcp.connect gives priority to options at tail, rather than head.
    socket_opts = opts |> Keyword.get(:socket_options, []) |> Enum.reverse(enforced_opts)

    with {:ok, socket} <- :gen_tcp.connect(hostname, port, socket_opts, connect_timeout) do
      # send ClientHandshake
      # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-client-handshake
      :ok =
        send_message(
          [
            <<
              @proto_ver_major::int16,
              @proto_ver_minor::int16,
              # number of params
              2::int16
            >>,
            # param 1
            str("user"),
            str(username),
            # param 2
            str("database"),
            str(database),
            # number of extensions
            <<0::int16>>
          ],
          0x56,
          socket
        )

      # handle ServerHandshake
      # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-server-handshake
      rest =
        case read_message!(socket) do
          <<0x76, _len::int32, major::int16, minor::int16, 0::int16, rest::binary>> ->
            if major !== @proto_ver_major or (@proto_ver_major == 0 and minor != @proto_ver_minor) do
              version = "#{major}.#{minor}"
              raise "The server requested an unsupported version of the protocol: #{version}"
            else
              rest
            end

          rest ->
            rest
        end

      # handle Authentication phase
      # https://edgedb.com/docs/internals/protocol/overview#authentication
      rest = handle_authentication(socket, rest, username, password)

      # handle ServerKeyData
      # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-server-key-data
      {<<_server_secret::size(32), _rest::binary>>, rest} = take_payload(rest, 0x4B)

      # handle ReadyForCommand
      # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-ready-for-command
      {<<
         # headers
         0::int16,
         # not in transaction
         0x49
       >>, ""} = take_payload(rest, 0x5A)

      {:ok, socket}
    end
  end

  defp handle_authentication(socket, data, username, password) do
    case data do
      # Auth method `Trust` (passwordless auth) is enabled
      # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-ok
      <<@msg_tag_authentication, _len::int32, 0::int32, rest::binary>> ->
        rest

      <<@msg_tag_authentication, _::binary>> = data ->
        handle_sasl_authentication(socket, data, username, password)
    end
  end

  defp handle_sasl_authentication(socket, data, username, password) do
    # handle AuthenticationSASL
    # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-sasl
    {<<
       # auth status
       0x0A::int32,
       # method count
       1::int32,
       # method 1
       string_length::int32,
       "SCRAM-SHA-256"
     >>, ""} = take_payload(data, @msg_tag_authentication)

    # send AuthenticationSASLInitialResponse
    # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-sasl-initial-response
    client_nonce = :crypto.strong_rand_bytes(18)

    client_first_bare = [
      "n=",
      String.normalize(username, :nfc),
      ",r=",
      Base.encode64(client_nonce)
    ]

    client_first = ["n,," | client_first_bare]
    client_first_length = IO.iodata_length(client_first)

    :ok =
      send_message(
        [<<string_length::int32, "SCRAM-SHA-256", client_first_length::int32>> | client_first],
        0x70,
        socket
      )

    # handle AuthenticationSASLContinue
    # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-sasl-continue
    {<<
       # auth status
       0x0B::int32,
       server_first_length::int32,
       server_first::binary-size(server_first_length)
     >>, ""} = socket |> read_message!() |> take_payload(@msg_tag_authentication)

    [<<"r=", server_nonce::binary>>, <<"s=", salt::binary>>, <<"i=", iterations::binary>>] =
      String.split(server_first, ",")

    salt = Base.decode64!(salt)
    {iterations, ""} = Integer.parse(iterations)

    # send AuthenticationSASLResponse
    # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-sasl-response
    client_final = ["c=biws,r=", server_nonce]
    auth_message = [client_first_bare, ",", server_first, "," | client_final]

    password = String.normalize(password, :nfc)

    h_i =
      password
      |> hmac_init()
      |> :crypto.mac_update(salt)
      |> :crypto.mac_update(<<0, 0, 0, 1>>)
      |> :crypto.mac_final()

    {salted_password, _} =
      Enum.reduce(0..(iterations - 2), {h_i, h_i}, fn _, {h_i, u_i} ->
        u_i = hmac(password, u_i)
        h_i = :crypto.exor(h_i, u_i)
        {h_i, u_i}
      end)

    client_key = hmac(salted_password, "Client Key")
    client_signature = hmac(hash(client_key), auth_message)
    client_proof = :crypto.exor(client_key, client_signature)

    :ok =
      [client_final, ",p=", Base.encode64(client_proof)]
      |> str()
      |> send_message(0x72, socket)

    # handle AuthenticationSASLFinal
    # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-sasl-final
    {<<0x0C::int32, server_final_length::int32, server_final::binary-size(server_final_length)>>,
     rest} = socket |> read_message!() |> take_payload(@msg_tag_authentication)

    <<"v=", server_signature::binary>> = server_final

    server_proof = salted_password |> hmac("Server Key") |> hmac(auth_message)
    ^server_proof = Base.decode64!(server_signature)

    # handle AuthenticationOK
    # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-auth-ok
    {<<0::int32>>, rest} = take_payload(rest, @msg_tag_authentication)

    rest
  end

  defp send_message(payload, message_type, socket) do
    # Add four because length includes self
    payload_length = IO.iodata_length(payload) + 4
    message = [<<message_type, payload_length::int32>> | payload]

    :gen_tcp.send(socket, message)
  end

  defp hash(value) do
    :crypto.hash(:sha256, value)
  end

  defp hmac(key, data) do
    :crypto.mac(:hmac, :sha256, key, data)
  end

  defp hmac_init(key) do
    :crypto.mac_init(:hmac, :sha256, key)
  end

  # https://edgedb.com/docs/internals/protocol/messages#ref-protocol-msg-error
  defp log_error_message(
         <<severity, code::int32, length::int32, message::binary-size(length), rest::binary>>
       ) do
    severity =
      case severity do
        120 -> ""
        200 -> "fatal: "
        255 -> "panic: "
      end

    _ = Logger.error("#{severity}#{message}, code: #{code}")

    if Logger.level() == :debug do
      <<num_headers::int16, rest::binary>> = rest

      Enum.reduce(1..num_headers, rest, fn _, <<_key::int16, len::int32, rest::binary>> ->
        {header, rest} = :erlang.split_binary(rest, len)
        _ = Logger.debug(header)
        rest
      end)
    end
  end

  defp take_payload(<<message_type, length::int32, rest::binary>>, message_type) do
    :erlang.split_binary(rest, length - 4)
  end

  defp read_message!(socket) do
    case :gen_tcp.recv(socket, 0) do
      # handle error message
      {:ok, <<0x45, _::binary>> = message} ->
        message |> take_payload(0x45) |> elem(0) |> log_error_message()
        raise "server responded with error"

      {:ok, data} ->
        data
    end
  end
end
