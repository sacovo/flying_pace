use f="files"

use "http_server"
use "templates"


class val FileTemplates
  let _base: f.FilePath val

  new val create(base: f.FilePath) =>
    _base = base

  fun val render(
    name: String val,
    request: Request,
    values: TemplateValues = TemplateValues,
    status: Status = StatusOK
    ): OneShotResponse^ =>
    try
      let body = render_to_string(name, request, values)?
      return (
        recover iso Responses.builder()
          .set_status(status)
        end
          ,
          body
        )
    end
    StatusInternalServerError

  fun val render_to_string(
    name: String val,
    request: Request,
    values: TemplateValues = TemplateValues
  ): String val? =>
    
    let path = _base.join(name)?
    let template = Template.from_file(path)?
    template.render(values)?


primitive Templates
  fun val render_string(
    template: String val,
    values: TemplateValues = TemplateValues
  ): String val? =>
    let template' = Template.parse(template)?
    template'.render(values)?

  fun val string_values(a: Iterator[(String val | Stringable box)]): TemplateValue =>
    let values = Array[TemplateValue box]

    match a
    | let a': Iterator[String val] =>
      for v in a' do
        values.push(TemplateValue(v))
      end
    | let a': Iterator[Stringable box] =>
      for v in a' do
        values.push(TemplateValue(v.string()))
      end
    end

    TemplateValue(values)
