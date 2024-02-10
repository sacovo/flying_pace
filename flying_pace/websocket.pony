use "collections"
use "debug"
use "encode/base64"
use "net"
use "promises"

use "crypto"
use "http_server"
use "logger"
use "regex"
use "valbytes"

interface val Opcode is Stringable
  fun box value(): U8 val

primitive Continuation
  fun box string(): String iso^ => "Continuation".clone()
  fun box value(): U8 val => 0x0

primitive Text
  fun box string(): String iso^ => "Text".clone()
  fun box value(): U8 val => 0x1

primitive Binary
  fun box string(): String iso^ => "Binary".clone()
  fun box value(): U8 val => 0x2

primitive Close
  fun box string(): String iso^ => "Close".clone()
  fun box value(): U8 val => 0x0

primitive Ping
  fun box string(): String iso^ => "Ping".clone()
  fun box value(): U8 val => 0x9

primitive Pong
  fun box string(): String iso^ => "Pong".clone()
  fun box value(): U8 val => 0xA


class WSMessage
  let content: ByteArrays
  let opcode: Opcode val
  let fin: Bool

  new val create(content': ByteArrays, opcode': Opcode val, fin': Bool) =>
    content = content'
    opcode = opcode'
    fin = fin'

  fun val add(msg: WSMessage val) =>
    WSMessage(ByteArrays(content, msg.content), opcode, msg.fin)

  fun val send_to(session: Session, request_id: USize val)? =>
    let data = encode()?
    session.send_chunk(data.array(), request_id)

  fun val encode(): ByteArrays? =>
    let b1 = if fin then
      0b1000_0000 or opcode.value()
    else
      opcode.value()
    end

    let length = content.size()

    let head: Array[U8 val] val = recover val
      let data = if length < 126 then
        let a = Array[U8 val](2)
        a.push(b1)
        a.push(length.u8())
        a
      elseif length <= U16.max_value().usize() then
        let a = Array[U8 val](4)
        a.push(b1)
        a.push(126)
        a.update_u16(2, length.u16())?
        a
      else
        let a = Array[U8 val](10)
        a.push(b1)
        a.push(127)
        a.update_u64(2, length.u64())?
        a
      end
      data
    end

    ByteArrays(head, content)


type FrameLength is (USize val, USize val)


primitive WSDecoder
  fun box payload_length(b: ByteArrays val): FrameLength? =>
    var l = USize.from[U8](b.read_u8(1)? and 0b0111_1111)
    if l < 126 then return (l, 2) end

    if l == 126 then
      (USize.from[U16](b.read_u16(2)?), 4)
    else
      (USize.from[U64](b.read_u64(2)?), 10)
    end

  fun box opcode(b: ByteArrays): Opcode val? => 
    let o = b.read_u8(0)? and 0b0000_1111
    Debug(o)
    match o
    | 0 => Continuation
    | 1 => Text
    | 2 => Binary
    | 8 => Close
    | 9 => Ping
    | 10 => Pong
    else
      error
    end

  fun box mask(b: ByteArrays, l: USize val): ByteArrays? =>
    let m = (b.read_u8(1)? and 0b1000_0000)
    if m == 0 then return ByteArrays end

    // There should be a mask with length 4 in the array!
    if b.size() < (l + 4) then error end

    recover val b.select(l, l + 4) end

  fun box fin(b: ByteArrays val): Bool? => (b.read_u8(0)? and 0b1000_0000) > 0

  fun box unmask(b: ByteArrays, mask': ByteArrays): Array[U8 val] iso^?  =>
    recover iso
      let b': Array[U8 val] ref = Array[U8 val](b.size())

      for i in Range[USize](0, b.size()) do
        b'.push(b(i)? xor mask'(i % 4)?)
      end
      b'
    end

  fun box decode(b': ByteArrays val): (WSMessage val | None, ByteArrays)? =>
    if b'.size() < 3 then
      return (None, b')
    end

    let fin' = fin(b')?
    let opcode' = opcode(b')?

    (let length, let pos) = payload_length(b')?

    let mask' = try
      mask(b', pos)?
    else
      // Not enough bytes to read mask
      return (None, b')
    end

    let start = pos + mask'.size()
    let stop = start + length

    if b'.size() < stop then
      return (None, b')
    end

    let payload = match mask'.size()
    | 0 => b'.select(start, stop)
    else
      ByteArrays(unmask(b'.select(start, stop), mask')?)
    end

    let remainder = if b'.size() > stop then b'.select(stop) else ByteArrays end
    (WSMessage(payload, opcode', fin'), remainder)


actor _WSHandler is ResponseHandler
  let gui: String val = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  let _session: Session
  let _request_id: USize val
  var _streaming: (WSResponse tag | None) = None
  let _router: URLRouter val
  let _request: Request val
  let _key: String val
  var _msg: (WSMessage val | None) = None
  var _buffer: ByteArrays = ByteArrays

  new create(
    session': Session,
    request_id': USize val,
    router: URLRouter val,
    request: Request val
  ) =>
    _session = session'
    _request = request
    _request_id = request_id'
    _router = router
    _key = try 
      request.header("Sec-WebSocket-Key") as String val
    else
      ""
    end

  fun box sec_accept(): String val =>
    Base64.encode(SHA1(_key + gui))

  be start() =>
    """
    """
    _session.send_raw(
      Responses.builder()
        .set_status(StatusSwitchingProtocols)
        .add_header("Upgrade", "websocket")
        .add_header("Connection", "upgrade")
        .add_header("Sec-WebSocket-Accept", sec_accept())
        .finish_headers()
        .build(),
      _request_id
    )
    

  be apply(r: OneShotResponse) =>
    """
    """

  be stream(r: StreamingResponse tag) =>
    """
    """
    try
      _streaming = r as WSResponse tag
    end

  be chunk(data: ByteSeq val) =>
    """
    """
    _buffer = _buffer + data

    (let result, _buffer) = try WSDecoder.decode(_buffer)? else Debug("Error in parsing msg"); return end

    let msg' = match result
    | let m: WSMessage val => m
    else
      return
    end


    match _msg
    | let m: WSMessage val => _msg = m + msg'
    else
      _msg = msg'
    end

    let msg = try _msg as WSMessage val else return end

    if not msg.fin then
      Debug("WSMessage is not done, continue...")
      return
    end

    Debug("WSMessage finished")

    _msg = None

    Debug(msg.opcode)

    match msg.opcode
    | Ping => _send_pong(msg)
    | Close => _close()
    | Binary => _send_msg(msg)
    | Text => _send_msg(msg)
    end


  be _send_msg(msg: WSMessage val) =>
    Debug("Sending message")
    match _streaming
    | let s: WSResponse tag => s.message(msg)
    end

    try
      msg.send_to(_session, _request_id)?
    else
      Debug("Error sending msg.")
    end

  be _send_pong(msg: WSMessage val) =>
    """
    """
    let pong = WSMessage(msg.content, msg.opcode, msg.fin)
    try
      pong.send_to(_session, _request_id)?
    else
      Debug("Error while sending pong!")
    end


  be _close() =>
    """
    """

  be finished(request_id: USize val) =>
    """
    """

  be cancel(request_id: USize) =>
    """
    """

  be dispose() =>
    """
    """
