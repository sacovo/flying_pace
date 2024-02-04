use "debug"
use "http_server"
use "pony_test"
use f="files"

use "templates"

use "flying_pace"


class iso _TestTemplate is UnitTest
  fun name(): String => "Templates"

  fun apply(h: TestHelper)? =>
    let t = "{{ name }}"
    let v = TemplateValues
    let name' = "Sandro"

    v("name") = name'

    h.assert_eq[String](
      Templates.render_string(t, v)?,
      name'
    )

    let ft = FileTemplates(f.FilePath(f.FileAuth(h.env.root), "templates"))

    match ft.render("index.html", TestRequest, v)
    | StatusInternalServerError => ""
    else
      error
    end

    v("values") = Templates.string_values(["Hallo"; "Welt"].values())

    match ft.render("index.html", TestRequest, v)
    | (let h': ResponseBuilderHeaders iso, let s: String val) =>
      s.find(name')?
      s.find("Welt")?
    else
      error
    end

    match ft.render("does_not_exist.html", TestRequest, v)
    | StatusInternalServerError => ""
    else
      error
    end
