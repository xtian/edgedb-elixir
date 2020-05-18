defmodule EdgeDB.Protocol.Records do
  @moduledoc false

  # import Record

  # # Types

  # # https://edgedb.com/docs/internals/protocol/dataformats#array
  # defrecord :array, [:ndims, :dimensions, :elements]
  # defrecord :array_dimension, [:upper, :lower]
  # defrecord :array_element, [:length, :data]

  # # https://edgedb.com/docs/internals/protocol/dataformats#tuple
  # defrecord :tuple, [:nelems, :elements]
  # defrecord :tuple_element, [:length, :data]

  # # https://edgedb.com/docs/internals/protocol/dataformats#std-decimal
  # @decimal_sign_pos 0x0000
  # @decimal_sign_neg 0x4000
  # defrecord :decimal, [:ndigits, :weight, :sign, :dscale, :digits]

  # # https://edgedb.com/docs/internals/protocol/dataformats#std-duration
  # defrecord :duration, [:microseconds, :days, :months]

  # # https://edgedb.com/docs/internals/protocol/dataformats#std-json
  # defrecord :json, [:jsondata]

  # # https://edgedb.com/docs/internals/protocol/dataformats#std-bigint
  # @big_int_sign_pos 0x0000
  # @big_int_sign_neg 0x4000
  # defrecord :bigint, [:ndigits, :weight, :sign, :reserved, :digits]

  # # Messages

  # defrecord :client_handshake, [:major_ver, :minor_ver, :num_params, :params, :num_exts, :exts]
  # defrecord :client_handshake_param, [:parameter_name, :parameter_value]
  # defrecord :client_handshake_protocol_ext, [:extname, :extheaders]
end
