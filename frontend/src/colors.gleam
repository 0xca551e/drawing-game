import lumi
import lumi/colorspace/hsluv
import lumi/colorspace/lchuv
import lumi/colorspace/luv
import lumi/colorspace/rgb
import lumi/colorspace/xyz

const gleam_black = "#1e1e1e"

const gleam_white = "#fefefc"

const gleam_faff_pink = "#ffaff3"

const gleam_unnamed_blue = "#a6f0fc"

fn mix_hex(a, b) {
  let a = rgb.from_hex(a)
  let b = rgb.from_hex(b)
  case a, b {
    Ok(a), Ok(b) ->
      Ok(
        lumi.Rgb(
          r: { a.r +. b.r } /. 2.0,
          g: { a.g +. b.g } /. 2.0,
          b: { a.b +. b.b } /. 2.0,
        )
        |> rgb.to_hex(True),
      )
    _, _ -> Error(Nil)
  }
}

fn from_hsluv(h: Float, s: Float, luv: Float) {
  lumi.Hsluv(h: h, s: s, luv: luv)
  |> hsluv.to_lchuv()
  |> lchuv.to_luv()
  |> luv.to_xyz()
  |> xyz.to_rgb()
  |> rgb.to_hex(True)
}

pub fn colors() {
  let assert Ok(gray) = mix_hex(gleam_black, gleam_white)
  [
    from_hsluv(10.0, 100.0, 60.0),
    from_hsluv(30.0, 100.0, 70.0),
    from_hsluv(60.0, 100.0, 83.0),
    from_hsluv(110.0, 100.0, 75.0),
    from_hsluv(240.0, 90.0, 55.0),
    from_hsluv(280.0, 50.0, 40.0),
    from_hsluv(40.0, 54.0, 48.0),
    gleam_black,
    gray,
    gleam_white,
    gleam_unnamed_blue,
    gleam_faff_pink,
  ]
}
