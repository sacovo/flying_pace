use "debug"

use "crypto"
use "valbytes"


class _ArrayOps
  let _ipad: Array[U8 val] val
  let _opad: Array[U8 val] val

  new create(block_size: USize val) =>
    _ipad = Array[U8].init(0x36, block_size)
    _opad = Array[U8].init(0x5C, block_size)

  fun ref _xor_arrays(a: Array[U8 val] val, b: Array[U8 val] val): Array[U8 val] val =>
    let l = a.size()
    recover val
      let c = Array[U8 val](l)
      var idx = USize(0)

      while idx < l do
        try
          let a' = a(idx)?
          let b' = b(idx)?
          c.push(a' xor b')
          idx = idx + 1
        end
      end

      c
    end

  fun ref ipad(key: Array[U8 val] val): Array[U8 val] val =>
    _xor_arrays(key, _ipad)

  fun ref opad(key: Array[U8 val] val): Array[U8 val] val =>
    _xor_arrays(key, _opad)


class val HMAC
  let hash: HashFn val
  let _ipadded: Array[U8 val] val
  let _opadded: Array[U8 val] val

  new val create(
    key': (String val | Array[U8 val] val),
    hash': HashFn val = SHA256
  ) =>
    hash = hash'

    let block_size: USize val = match hash
    | SHA256 => 64
    | SHA384 => 128
    | SHA512 => 128
    else
      64
    end

    let k' = match key'
    | let k: String val => k.array()
    | let k: Array[U8 val] val => k
    end
    // Restrict length of key to max. 64
    let k = if k'.size() < block_size then k' else hash(k') end
    // key needs to be padded with 0 to length 64
    let key = recover val
      let key_array = Array[U8].init(0x00, block_size)
      k.copy_to(key_array, 0, 0, k.size())
      key_array
    end
    let tools = _ArrayOps(block_size)
    _ipadded = tools.ipad(key)
    _opadded = tools.opad(key)

  fun val apply(msg: (String val | Array[U8 val] val)): Array[U8 val] val =>
    let msg' = match msg
    | let m: String val => m.array()
    | let m: Array[U8 val] val => m
    end
    let inner = hash(ByteArrays(_ipadded, msg').array())
    hash(ByteArrays(_opadded, inner).array())
