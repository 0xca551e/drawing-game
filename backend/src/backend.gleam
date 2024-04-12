import carpenter/table
import glanoid
import gleam/bytes_builder
import gleam/dict
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/pair
import gleam/result
import gleam/string
import jasper as j
import mist.{type Connection, type ResponseData}

const games_table = "games"

type Point {
  Point(x: Int, y: Int)
}

fn point_to_json(point: Point) {
  j.Array([j.Number(int.to_float(point.x)), j.Number(int.to_float(point.y))])
}

type Stroke {
  Stroke(color: String, thickness: Int, sequence: List(Point))
}

fn stroke_to_json(stroke: Stroke) {
  j.Object(
    dict.from_list([
      #("color", j.String(stroke.color)),
      #("thickness", j.Number(int.to_float(stroke.thickness))),
      #("sequence", j.Array(list.map(stroke.sequence, point_to_json))),
    ]),
  )
}

type Drawing {
  Drawing(
    selected_color: String,
    selected_thickness: Int,
    strokes: List(Stroke),
  )
}

fn drawing_to_json(drawing: Drawing) {
  j.Object(
    dict.from_list([
      #("selected_color", j.String(drawing.selected_color)),
      #(
        "selected_thickness",
        j.Number(int.to_float(drawing.selected_thickness)),
      ),
      #("strokes", j.Array(list.map(drawing.strokes, stroke_to_json))),
    ]),
  )
}

type User {
  User(id: String, name: String, conn: mist.WebsocketConnection)
}

type GameState {
  GameState(drawing: Drawing, users: List(User))
}

type SocketState {
  SocketState(user_id: String, game_id: String)
}

pub type MyMessage {
  Broadcast(String)
}

fn find_game(id) -> Result(GameState, Nil) {
  let assert Ok(games) = table.ref(games_table)
  games
  |> table.lookup(id)
  |> list.first()
  |> result.map(pair.second)
}

fn upsert_game_with(id, updater: fn(GameState) -> GameState) {
  let assert Ok(games) = table.ref(games_table)
  case find_game(id) {
    Ok(game) -> {
      let new_game = updater(game)
      table.insert(games, [#(id, new_game)])
      Ok(new_game)
    }
    _ -> Error(Nil)
  }
}

pub fn main() {
  let nanoid = glanoid.make_generator(glanoid.default_alphabet)
  let selector = process.new_selector()

  let example_game_id = nanoid(18)

  let assert Ok(games): Result(table.Set(String, GameState), Nil) =
    table.build(games_table)
    |> table.privacy(table.Public)
    |> table.write_concurrency(table.NoWriteConcurrency)
    |> table.read_concurrency(True)
    |> table.decentralized_counters(True)
    |> table.compression(False)
    |> table.ordered_set()

  table.insert(games, [
    #(
      example_game_id,
      GameState(
        drawing: Drawing(
          selected_color: "#1e1e1e",
          selected_thickness: 4,
          strokes: [],
        ),
        users: [],
      ),
    ),
  ])

  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_builder.new()))

  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(conn) {
              let user_id = nanoid(18)

              let assert Ok(game) =
                upsert_game_with(example_game_id, fn(game) {
                  GameState(
                    ..game,
                    users: list.append(game.users, [
                      User(id: user_id, name: "unnamed user", conn: conn),
                    ]),
                  )
                })
              let init_msg =
                game.drawing
                |> drawing_to_json()
                |> j.stringify_json()
              let _ = mist.send_text_frame(conn, "init," <> init_msg)
              #(
                SocketState(user_id: user_id, game_id: example_game_id),
                Some(selector),
              )
            },
            on_close: fn(_state) {
              let assert Ok(#(id, game)): Result(#(String, GameState), Nil) =
                games
                |> table.lookup(example_game_id)
                |> list.first()
              games
              |> table.insert([
                #(
                  id,
                  GameState(
                    ..game,
                    users: list.filter(game.users, fn(x) { x.id != x.id }),
                  ),
                ),
              ])
            },
            handler: handle_ws_message,
          )
        _ -> not_found
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

fn relay_to_others(state: SocketState, message) {
  let assert Ok(game) = find_game(state.game_id)
  list.filter(game.users, fn(x) { x.id != state.user_id })
  |> list.each(fn(x) {
    let _ = mist.send_text_frame(x.conn, message)
  })
}

fn handle_ws_message(state: SocketState, conn, message) {
  case message {
    mist.Text("ping") -> {
      actor.continue(state)
    }
    mist.Text(msg) -> {
      let parts = string.split(msg, ",")
      let next_state = case parts {
        ["ping"] -> {
          let _ = mist.send_text_frame(conn, "pong")
          state
        }
        ["pen_color", color] -> {
          let _ =
            upsert_game_with(state.game_id, fn(game) {
              GameState(
                ..game,
                drawing: Drawing(..game.drawing, selected_color: color),
              )
            })
          relay_to_others(state, msg)

          state
        }
        ["pen_thickness", thickness] -> {
          let assert Ok(thickness) = int.parse(thickness)
          let _ =
            upsert_game_with(state.game_id, fn(game) {
              GameState(
                ..game,
                drawing: Drawing(..game.drawing, selected_thickness: thickness),
              )
            })
          relay_to_others(state, msg)

          state
        }
        ["begin", x, y] -> {
          let assert Ok(x) = int.parse(x)
          let assert Ok(y) = int.parse(y)
          let _ =
            upsert_game_with(state.game_id, fn(game) {
              GameState(
                ..game,
                drawing: Drawing(
                  ..game.drawing,
                  strokes: list.append(game.drawing.strokes, [
                    Stroke(
                      color: game.drawing.selected_color,
                      thickness: game.drawing.selected_thickness,
                      sequence: [Point(x: x, y: y)],
                    ),
                  ]),
                ),
              )
            })
          relay_to_others(state, msg)

          state
        }
        ["draw", x, y] -> {
          let assert Ok(x) = int.parse(x)
          let assert Ok(y) = int.parse(y)

          let _ =
            upsert_game_with(state.game_id, fn(game) {
              let strokes_init =
                list.take(
                  game.drawing.strokes,
                  list.length(game.drawing.strokes) - 1,
                )
              let assert Ok(strokes_last) = list.last(game.drawing.strokes)
              let updated_stroke =
                Stroke(
                  ..strokes_last,
                  sequence: list.append(strokes_last.sequence, [
                    Point(x: x, y: y),
                  ]),
                )
              let updated_strokes = list.append(strokes_init, [updated_stroke])

              GameState(
                ..game,
                drawing: Drawing(..game.drawing, strokes: updated_strokes),
              )
            })
          relay_to_others(state, msg)

          state
        }
        _ -> panic as "the ditco"
      }
      io.println(msg)
      actor.continue(next_state)
    }
    mist.Binary(_) | mist.Custom(_) -> {
      actor.continue(state)
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}
