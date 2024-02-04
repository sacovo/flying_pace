use "collections"
use "debug"
use "time"
use f = "files"

use "http_server"
use "templates"
use "regex"
use "valbytes"


actor FileStream is StreamingResponse
  var _buffer: Array[U8 val] iso = Array[U8 val](1024 * 5) 
  var _session: (Session | None) = None
  var _request_id: (USize val | None) = None
  var _sent: USize val = 0
  let _response: ResponseBuilderHeaders ref

  new create(response': ResponseBuilderHeaders iso) =>
    _response = consume response'

  be send_chunk(b: Array[U8 val] val) =>
    _sent = _sent + b.size()
    Debug("Sent: " + _sent.string())
    match (_session, _request_id)
    | (let session: Session, let request_id: USize val) =>
        session.send_chunk(consume b, request_id)
    else
      _buffer.append(consume b)
    end

  be apply(session: Session, request_id: USize val) =>
    _session = session
    _request_id = request_id
    let data = _buffer = Array[U8 val]()

    session.send_chunk(consume data, request_id)

  fun ref response(): ResponseBuilderHeaders ref =>
    _response

  be done() =>
    match (_session, _request_id)
    | (let s: Session, let r: USize val) =>
      s.send_finished(r)
      _session = None
      _request_id = None
    end

  be dispose() =>
    Debug("Disposing file stream")


interface NameValidator
  fun box apply(name: String val): Bool


class ServeDirectory is URLHandler
  let _base: f.FilePath
  let _cache: Bool
  let _max_age: USize
  let _validator: (NameValidator box | None)
  let _list_dir: Bool

  new create(
    path: f.FilePath,
    cache: Bool = true,
    max_age: USize = 0,
    validator: (NameValidator box | None) = None,
    list_dir: Bool = false
  ) =>
    _base = path
    _cache = cache
    _max_age = max_age
    _validator = validator
    _list_dir = list_dir

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

    if info.directory then
      if _list_dir then
        try show_file_listings(path, name, p)? end
      else
        p(StatusNotFound)
      end
    end

    match f.OpenFile(path)
    | let file: f.File =>
        let response = if _cache then
          let etag = _get_etag(file)

          if _check_etag(r, etag) then
            return p(StatusNotModified)
          end

          recover iso Responses.builder()
            .set_status(StatusOK)
            .add_header("Etag", etag)
            .add_header("Cache-Control", "max-age="+_max_age.string()+", must-revalidate")
            .add_header("Content-Length", file.size().string())
          end
        else
          recover iso
          Responses.builder()
            .set_status(StatusOK)
            .add_header("Content-Length", file.size().string())
          end
        end

        let stream = FileStream(consume response)
        p.stream(stream)

        while file.errno() is f.FileOK do
          stream.send_chunk(file.read(1024 * 10))
        end

        stream.done()
        file.dispose()
    else
      p(StatusNotFound)
    end
