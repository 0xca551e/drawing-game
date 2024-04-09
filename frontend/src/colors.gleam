import lumi
import lumi/colorspace/hsluv
import lumi/colorspace/lchuv
import lumi/colorspace/luv
import lumi/colorspace/rgb
import lumi/colorspace/xyz

pub const gleam_black = "#1e1e1e"

pub const gleam_white = "#fefefc"

pub const gleam_faff_pink = "#ffaff3"

pub const gleam_unnamed_blue = "#a6f0fc"

pub fn mix_hex(a, b) {
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

pub fn from_hsluv(h: Float, s: Float, luv: Float) {
  lumi.Hsluv(h: h, s: s, luv: luv)
  |> hsluv.to_lchuv()
  |> lchuv.to_luv()
  |> luv.to_xyz()
  |> xyz.to_rgb()
  |> rgb.to_hex(True)
}
