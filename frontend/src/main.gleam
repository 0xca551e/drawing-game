import colors
import gleam/int
import gleam/javascript.{type Reference} as js
import gleam/list
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import pprint

type HtmlElement

type MouseEvent

pub type CanvasRenderingContext2D

type HtmlElementPosition {
  HtmlElementPosition(left: Int, top: Int)
}

@external(javascript, "./external.js", "getPosition")
fn get_position(element: HtmlElement) -> HtmlElementPosition

@external(javascript, "./external.js", "getDocument")
fn document() -> HtmlElement

@external(javascript, "./external.js", "addEventListenerMouseUp")
fn add_event_listener_mouse_up(
  target: HtmlElement,
  callback: fn(MouseEvent) -> Nil,
) -> Nil

@external(javascript, "./external.js", "addEventListenerMouseDown")
fn add_event_listener_mouse_down(
  target: HtmlElement,
  callback: fn(MouseEvent) -> Nil,
) -> Nil

@external(javascript, "./external.js", "addEventListenerMouseMove")
fn add_event_listener_mouse_move(
  target: HtmlElement,
  callback: fn(MouseEvent) -> Nil,
) -> Nil

@external(javascript, "./external.js", "requestAnimationFrame")
fn request_animation_frame(callback: fn(Int) -> Nil) -> Nil

@external(javascript, "./external.js", "querySelector")
fn query_selector(selector: String) -> Result(HtmlElement, Nil)

@external(javascript, "./external.js", "mouseX")
fn event_mouse_x(e: MouseEvent) -> Int

@external(javascript, "./external.js", "mouseY")
fn event_mouse_y(e: MouseEvent) -> Int

@external(javascript, "./external.js", "getContext")
fn get_context(element: HtmlElement) -> CanvasRenderingContext2D

@external(javascript, "./external.js", "setStrokeStyle")
fn set_stroke_style(
  ctx: CanvasRenderingContext2D,
  color: String,
) -> CanvasRenderingContext2D

@external(javascript, "./external.js", "setLineWidth")
fn set_line_width(
  ctx: CanvasRenderingContext2D,
  width: Int,
) -> CanvasRenderingContext2D

@external(javascript, "./external.js", "beginPath")
fn begin_path(ctx: CanvasRenderingContext2D) -> CanvasRenderingContext2D

@external(javascript, "./external.js", "moveTo")
fn move_to(
  ctx: CanvasRenderingContext2D,
  x: Int,
  y: Int,
) -> CanvasRenderingContext2D

@external(javascript, "./external.js", "lineTo")
fn line_to(
  ctx: CanvasRenderingContext2D,
  x: Int,
  y: Int,
) -> CanvasRenderingContext2D

@external(javascript, "./external.js", "stroke")
fn stroke(ctx: CanvasRenderingContext2D) -> CanvasRenderingContext2D

fn draw_line(
  ctx: CanvasRenderingContext2D,
  x1,
  y1,
  x2,
  y2,
  color color: String,
  thickness thickness: Int,
) {
  ctx
  |> set_stroke_style(color)
  |> set_line_width(thickness)
  |> begin_path()
  |> move_to(x1, y1)
  |> line_to(x2, y2)
  |> stroke()
}

type Model {
  Model(
    rendering_context: Result(Reference(CanvasRenderingContext2D), Nil),
    drawing_at: Result(#(Int, Int), Nil),
    pen_color: String,
    pen_thickness: Int,
  )
}

pub type Msg {
  SetRenderingContext(CanvasRenderingContext2D)
  BeginDrawing(Int, Int)
  TryDraw(Int, Int)
  EndDrawing
  SetColor(String)
  SetPenSize(Int)
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(
    Model(
      rendering_context: Error(Nil),
      drawing_at: Error(Nil),
      pen_color: "#000000",
      pen_thickness: 4,
    ),
    effect.from(fn(dispatch) {
      request_animation_frame(fn(_) {
        let assert Ok(canvas) = query_selector("#canvas")
        let ctx = get_context(canvas)
        dispatch(SetRenderingContext(ctx))

        add_event_listener_mouse_down(canvas, fn(e) {
          let position = get_position(canvas)
          dispatch(BeginDrawing(
            event_mouse_x(e) - position.left,
            event_mouse_y(e) - position.top,
          ))
        })
        add_event_listener_mouse_up(document(), fn(_) { dispatch(EndDrawing) })
        add_event_listener_mouse_move(document(), fn(e) {
          let position = get_position(canvas)
          dispatch(TryDraw(
            event_mouse_x(e) - position.left,
            event_mouse_y(e) - position.top,
          ))
        })
      })
    }),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SetRenderingContext(ctx) -> #(
      Model(..model, rendering_context: Ok(js.make_reference(ctx))),
      effect.none(),
    )
    BeginDrawing(x, y) -> #(
      Model(..model, drawing_at: Ok(#(x, y))),
      effect.none(),
    )
    TryDraw(x2, y2) -> #(
      Model(
        ..model,
        drawing_at: case model.drawing_at {
          Ok(_) -> Ok(#(x2, y2))
          _ -> model.drawing_at
        },
      ),
      effect.from(fn(_) {
        case model.drawing_at {
          Ok(#(x1, y1)) -> {
            let assert Ok(ctx) = model.rendering_context
            let ctx = js.dereference(ctx)
            draw_line(
              ctx,
              x1,
              y1,
              x2,
              y2,
              color: model.pen_color,
              thickness: model.pen_thickness,
            )
            Nil
          }
          _ -> Nil
        }
      }),
    )
    EndDrawing -> #(Model(..model, drawing_at: Error(Nil)), effect.none())
    SetColor(color) -> #(Model(..model, pen_color: color), effect.none())
    SetPenSize(size) -> #(Model(..model, pen_thickness: size), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let assert Ok(gray) = colors.mix_hex(colors.gleam_black, colors.gleam_white)
  let colors = [
    colors.from_hsluv(10.0, 100.0, 60.0),
    colors.from_hsluv(30.0, 100.0, 70.0),
    colors.from_hsluv(60.0, 100.0, 83.0),
    colors.from_hsluv(110.0, 100.0, 75.0),
    colors.from_hsluv(240.0, 90.0, 55.0),
    colors.from_hsluv(280.0, 50.0, 40.0),
    colors.from_hsluv(40.0, 54.0, 48.0),
    colors.gleam_black,
    gray,
    colors.gleam_white,
    colors.gleam_unnamed_blue,
    colors.gleam_faff_pink,
  ]
  let palette_color = fn(color) {
    html.span(
      [
        attribute.role("button"),
        attribute.class("palette__color"),
        attribute.style([#("background-color", color)]),
        event.on_click(SetColor(color)),
      ],
      [],
    )
  }
  let pen_sizes = [4, 8, 16, 32]
  let pen = fn(size) {
    html.span(
      [
        attribute.role("button"),
        attribute.class("pen"),
        event.on_click(SetPenSize(size)),
      ],
      [
        html.span(
          [
            attribute.class("pen__preview"),
            attribute.style([
              #("width", int.to_string(size) <> "px"),
              #("height", int.to_string(size) <> "px"),
              #("background-color", model.pen_color),
            ]),
          ],
          [],
        ),
      ],
    )
  }
  html.div([], [
    html.div([attribute.class("palette")], list.map(colors, palette_color)),
    html.div([attribute.class("pens")], list.map(pen_sizes, pen)),
    html.canvas([
      attribute.id("canvas"),
      attribute.width(640),
      attribute.height(480),
    ]),
    html.code([], [element.text(pprint.format(model))]),
  ])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(dispatch) = lustre.start(app, "#app", Nil)

  dispatch
}
