defmodule EdgeDB.Protocol.Types do
  @moduledoc false

  # https://edgedb.com/docs/internals/protocol/dataformats#std-int16
  defmacro int16, do: quote(do: 16 - big - signed)
  defmacro int32, do: quote(do: 32 - big - signed)
  defmacro int64, do: quote(do: 64 - big - signed)

  # https://edgedb.com/docs/internals/protocol/dataformats#std-str
  def str(iodata) do
    length = IO.iodata_length(iodata)
    [<<length::int32>> | iodata]
  end
end
