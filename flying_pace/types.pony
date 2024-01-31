use "valbytes"
use "http_server"


trait StreamingResponse

  be init(session: Session, request_id: USize val) =>
    session.send_start(response(), request_id)

  be apply(session: Session, request_id: USize val)

  fun response(): Response val =>
    BuildableResponse(StatusOK where transfer_coding' = Chunked)

  be cancel(request_id: USize val) =>
    """
    """

trait Responsable
  fun response(): (Response val, ResponseBody)

type ResponseBody is (String val | ByteArrays val)
type OneShotResponse is ((Response val, ResponseBody) | Response val | ResponseBody | Status val | Responsable val)
type ResponseType is (OneShotResponse val | StreamingResponse tag)

