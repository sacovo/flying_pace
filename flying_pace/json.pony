use "http_server"
use "json"
use "valbytes"


primitive JSON

  fun val render(
    doc: JsonDoc,
    status: Status = StatusOK,
    pretty_print: Bool = false,
    indent: String val = ""
  ): OneShotResponse^ =>
    let content = render_string(doc, status, pretty_print, indent)
    let r = BuildableResponse(status where content_length'=content.size())

    (
      recover iso 
        Responses.builder()
          .set_status(status)
      end, 
      content
    )

  fun val render_string(
    doc: JsonDoc,
    status: Status = StatusOK,
    pretty_print: Bool = false,
    indent: String val = ""
  ): String val =>
    doc.string(where indent=indent, pretty_print=pretty_print)

  fun val parse(b: ByteArrays): (JsonDoc | (USize val, String val))=>
    let doc = JsonDoc
    try
      doc.parse(b.string())?
      doc
    else
      doc.parse_report()
    end
