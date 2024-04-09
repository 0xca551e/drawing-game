import gleam/javascript.{type Reference} as js
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import pprint

type HtmlElement

type MouseEvent

pub type CanvasRenderingContext2D

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

@external(javascript, "./external.js", "eventTarget")
fn mouse_event_target(e: MouseEvent) -> HtmlElement

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
          dispatch(BeginDrawing(event_mouse_x(e), event_mouse_y(e)))
        })
        add_event_listener_mouse_up(document(), fn(_) { dispatch(EndDrawing) })
        add_event_listener_mouse_move(document(), fn(e) {
          dispatch(TryDraw(event_mouse_x(e), event_mouse_y(e)))
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
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
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
