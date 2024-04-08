import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

type Model {
  Model
}

pub type Msg {
  Msg
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(Model, effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [element.text("Hello world")])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(dispatch) = lustre.start(app, "#app", Nil)

  dispatch
}
