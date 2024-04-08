import "normalize.css";
import "./style.css";
import { main } from "./main.gleam";

document.addEventListener("DOMContentLoaded", () => {
  const dispatch = main({});
});