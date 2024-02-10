use "collections"
use "time"
use "debug"
use f = "files"

use "http_server"
use "templates"
use "regex"
use "valbytes"


class iso _FileStreamNotify is TimerNotify
  let _stream: FileStream

  new iso create(stream: FileStream tag) =>
    _stream = stream

  fun ref apply(timer: Timer ref, count: U64 val): Bool =>
    _stream.read_chunk()
    true


actor FileStream is StreamingResponse
  let _file: (f.File ref | None)

  var _session: (Session | None) = None
  var _request_id: (USize val | None) = None
  var _sent: USize val = 0

  let _request: Request

  let _cache: Bool
  let _max_age: USize val

  let _timers: Timers
  var _timer: (Timer tag | None) = None

  let _chunk_size: USize val
  let _read_timeout: USize val

  new create(
    path: f.FilePath,
    request: Request,
    cache: Bool,
    max_age: USize val,
    timers: Timers,
    chunk_size: USize val,
    read_timeout: USize val
  ) =>
    _file = match f.OpenFile(path)
    | let file: f.File => file
    else
      None
    end
    _cache = cache
    _request = request
    _max_age = max_age
    _timers = timers
    _chunk_size = chunk_size
    _read_timeout = read_timeout

  fun ref response(): ResponseBuilderHeaders ref =>
    match _file
    | let file: f.File =>
      if _cache then
        let etag = _get_etag(file)

        if _check_etag(_request, etag) then
          Responses.builder().set_status(StatusNotModified).add_header("Content-Length", "0")
        else
          Responses.builder()
            .set_status(StatusOK)
            .add_header("Etag", etag)
            .add_header("Cache-Control", "max-age="+_max_age.string()+", must-revalidate")
            .add_header("Content-Length", file.size().string())
        end
      else
        Responses.builder()
          .set_status(StatusOK)
          .add_header("Content-Length", file.size().string())
      end
    else
      Responses.builder()
        .set_status(StatusNotFound)
        .add_header("Content-Length", "0")
    end

  be apply(session: Session, request_id: USize val) =>
    _session = session
    _request_id = request_id

    let timer = Timer(_FileStreamNotify(this), 1, 5_000)
    _timer = timer
    _timers(consume timer)

  be send_chunk(b: Array[U8 val] val) =>
    match (_session, _request_id)
    | (let session: Session, let request_id: USize val) =>
        session.send_chunk(consume b, request_id)
    end

  be read_chunk() =>
    match _file
    | let file: f.File =>
      if file.errno() is f.FileOK then
        send_chunk(file.read(500_000))
      else
        dispose()
      end
    end

  be cancel(request_id: USize val) =>
    dispose()

  be dispose() =>
    match (_session, _request_id)
    | (let s: Session, let r: USize val) =>
      s.send_finished(r)
      _session = None
      _request_id = None
    end

    match _timer
    | let timer: Timer tag => _timers.cancel(timer)
    end

    match _file
    | let file: f.File => file.dispose()
    end

  fun box _get_etag(file: f.File): String val =>
    (let t, let n) = try file.info()?.modified_time else Time.now() end
    t.string()

  fun box _check_etag(r: Request val, etag: String val): Bool =>
    match r.header("If-None-Match")
    | let s: String val => etag == s
    else
      false
    end


interface NameValidator
  fun box apply(name: String val): Bool


class ServeDirectory is URLHandler
  let _base: f.FilePath
  let _cache: Bool
  let _max_age: USize
  let _validator: (NameValidator box | None)
  let _list_dir: Bool
  let _timers: Timers = Timers
  let _read_timeout: USize val
  let _chunk_size: USize val

  new create(
    path: f.FilePath,
    cache: Bool = true,
    max_age: USize = 0,
    validator: (NameValidator box | None) = None,
    list_dir: Bool = false,
    chunk_size: USize val = 500_000_000,
    read_timeout: USize val = 5_000
  ) =>
    _base = path
    _cache = cache
    _max_age = max_age
    _validator = validator
    _list_dir = list_dir
    _chunk_size = chunk_size
    _read_timeout = read_timeout

  fun _validate_name(name: String val): Bool =>
    match _validator
    | let v: NameValidator box => v(name)
    else
      true
    end

  fun box _get_etag(file: f.File): String val =>
    (let t, let n) = try file.info()?.modified_time else Time.now() end
    t.string()

  fun box _check_etag(r: Request val, etag: String val): Bool =>
    match r.header("If-None-Match")
    | let s: String val => etag == s
    else
      false
    end

  fun box show_file_listings(path: f.FilePath, name: String val, p: ResponseHandler tag)? =>
    """
    """
    let dir = f.Directory(path)?
    let template = """
<html>
<head><title>Index of /{{ name }}</title></head>
<body>
<h1>Index of /{{ name }}</h1><hr/><pre>
{{ for folder in folders }}<a href="{{folder}}">{{folder}}</a>
{{ end }}{{ for file in files }}<a href="{{file}}">{{file}}</a>
{{ end }}</pre><hr></body>
</html>
    """
    let values = TemplateValues
    let files = Array[TemplateValue box]
    let folders = Array[TemplateValue box]

    for entry in dir.entries()?.values() do
      let info = f.FileInfo(path.join(entry)?)?
      if info.directory then
        folders.push(TemplateValue(entry + "/"))
      else
        files.push(TemplateValue(entry))
      end
    end

    values("files") = TemplateValue(files)
    values("folders") = TemplateValue(folders)
    values("name") = name
    try
      p(Templates.render_string(template, values)?)
    else
      p(ServerError("Could not render template!"))
    end

  fun box apply(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let name = try recover val m.find[String iso]("path")? end else return p(StatusNotFound) end

    if not _validate_name(name) then return p(StatusNotFound) end

    let path = try _base.join(name)? else return p(StatusNotFound) end
    let info = try f.FileInfo(path)? else return p(StatusNotFound) end

    if info.file then
      let stream = FileStream(path, r, _cache, _max_age, _timers, _chunk_size, _read_timeout)
      p.stream(stream)
    elseif info.directory and _list_dir then
      try show_file_listings(path, name, p)? else p(ServerError("Error in file listing")) end
    else
      p(StatusNotFound)
    end
