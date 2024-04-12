import colors
import gleam/bool
import gleam/int
import gleam/javascript.{type Reference} as js
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre_websocket as ws
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

type Model {
  Model(
    rendering_context: Result(Reference(CanvasRenderingContext2D), Nil),
    socket: Result(ws.WebSocket, Nil),
    drawing: Bool,
    pen_color: String,
    pen_thickness: Int,
  )
}

pub type Msg {
  WsWrapper(ws.WebSocketEvent)
  SetSocket(ws.WebSocket)
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
      socket: Error(Nil),
      drawing: False,
      pen_color: "#000000",
      pen_thickness: 4,
    ),
    effect.batch([
      ws.init("/ws", WsWrapper),
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
    ]),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    WsWrapper(event) -> #(
      model,
      effect.from(fn(dispatch) {
        let wrapper = case event {
          ws.InvalidUrl -> panic
          ws.OnOpen(socket) -> dispatch(SetSocket(socket))
          ws.OnTextMessage(msg) -> todo as "handle text message"
          ws.OnBinaryMessage(bits) -> todo as "handle binary message"
          ws.OnClose(reason) -> todo as "handle close"
        }
      }),
    )
    SetSocket(socket) -> #(Model(..model, socket: Ok(socket)), effect.none())
    SetRenderingContext(ctx) -> #(
      Model(..model, rendering_context: Ok(js.make_reference(ctx))),
      effect.none(),
    )
    BeginDrawing(x, y) -> #(Model(..model, drawing: True), {
      let assert Ok(socket) = model.socket
      effect.batch([
        ws.send(
          socket,
          string.join(["begin", int.to_string(x), int.to_string(y)], ","),
        ),
        effect.from(fn(_) {
          let assert Ok(ctx) = model.rendering_context
          ctx
          |> js.dereference()
          |> set_stroke_style(model.pen_color)
          |> set_line_width(model.pen_thickness)
          |> begin_path()
          |> move_to(x, y)
          Nil
        }),
      ])
    })
    TryDraw(x, y) -> #(model, {
      use <- bool.guard(!model.drawing, effect.none())
      let assert Ok(socket) = model.socket
      effect.batch([
        ws.send(
          socket,
          string.join(["draw", int.to_string(x), int.to_string(y)], ","),
        ),
        effect.from(fn(_) {
          let assert Ok(ctx) = model.rendering_context
          ctx
          |> js.dereference()
          |> line_to(x, y)
          |> stroke()
          Nil
        }),
      ])
    })
    EndDrawing -> #(Model(..model, drawing: False), effect.none())
    SetColor(color) -> #(Model(..model, pen_color: color), {
      let assert Ok(socket) = model.socket
      ws.send(socket, string.join(["pen_color", color], ","))
    })
    SetPenSize(size) -> #(Model(..model, pen_thickness: size), {
      let assert Ok(socket) = model.socket
      ws.send(socket, string.join(["pen_thickness", int.to_string(size)], ","))
    })
  }
}

fn view(model: Model) -> Element(Msg) {
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
    html.div(
      [attribute.class("palette")],
      list.map(colors.colors(), palette_color),
    ),
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
