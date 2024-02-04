use "collections"
use "debug"

use "http_server"
use "valbytes"


primitive POSTData

  fun val decode(request: Request, b: ByteArrays): Params val? =>
    match request.header("Content-Type")
    | "application/x-www-form-urlencoded" => _decode_urlencoded(b)
    | "multipart/form-data" => _decode_form_data(b)?
    else
      error
    end

  fun val _decode_urlencoded(b: ByteArrays): Params val =>
    Params(b.string())

  fun val _decode_form_data(b: ByteArrays): Params val? =>
    error


type ParamDict is HashMap[String, Array[String], HashEq[String]]


class ParseParams
  fun ref apply(query: String val): ParamDict =>
    let split_array: Array[String] = query.split("&")

    let result = HashMap[String, Array[String], HashEq[String]].create()

    for param in split_array.values() do
      let split = param.split("=", 2)
      let key = try split(0)? else continue end
      let value = _urldecode(try split(1)? else "" end)
      try
        result(key)?.push(value)
      else
        result(key) = [value]
      end
    end
    result

  fun ref _urldecode(input: String val): String val =>
    let result = recover val
      let r: String ref = String(input.size())

      var byte_pos: ISize = -1
      var byte: Array[U8] trn = Array[U8](2)

      for c in input.values() do
        if \unlikely\ c == '%' then
          byte_pos = 0
        elseif \unlikely\ byte_pos == 0 then
          byte_pos = byte_pos + 1
          byte.push(c)
        elseif \unlikely\ byte_pos == 1 then
          byte_pos = -1
          byte.push(c)
          let b = consume byte
          byte = Array[U8](2)
          let s = String.from_array(consume b)
          try
            r.push(s.u8(16)?)
          else
            Debug("This didn't work, s=" + s)
          end
        elseif c == '+' then
          r.push(' ')
        else
          r.push(c)
        end
      end
      r
    end
    result


class Params
  let _params: HashMap[String, Array[String], HashEq[String]] val
  
  new val create(query: String val) =>
    _params = recover val ParseParams(query) end

  fun box apply(key: String val, default: String val = ""): String val  =>
    try _params(key)?(0)? else default end
    
  fun box list(key: String val): Array[String] val =>
    try _params(key)? else [] end
