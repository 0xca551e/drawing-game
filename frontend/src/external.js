import { Ok, Error } from "../build/dev/javascript/prelude.mjs";

export function getPosition(element) {
  var clientRect = element.getBoundingClientRect();
  return {
    left: clientRect.left + document.body.scrollLeft,
    top: clientRect.top + document.body.scrollTop,
  };
}

export function getDocument() {
  return document;
}

export function addEventListenerMouseUp(target, callback) {
  return target.addEventListener("mouseup", callback);
}

export function addEventListenerMouseDown(target, callback) {
  return target.addEventListener("mousedown", callback);
}

export function addEventListenerMouseMove(target, callback) {
  return target.addEventListener("mousemove", callback);
}

export function requestAnimationFrame(callback) {
  return window.requestAnimationFrame(callback);
}

export function querySelector(selector) {
  let found = document.querySelector(selector);
  if (!found) {
    return new Error();
  }
  return new Ok(found);
}

export function eventTarget(event) {
  return event.target;
}

export function mouseX(event) {
  return event.pageX;
}

export function mouseY(event) {
  return event.pageY;
}

export function getContext(element) {
  return element.getContext("2d");
}

export function setStrokeStyle(ctx, color) {
  ctx.strokeStyle = color;
  return ctx;
}

export function setLineWidth(ctx, lineWidth) {
  ctx.lineWidth = lineWidth;
  return ctx;
}

export function beginPath(ctx) {
  ctx.beginPath();
  return ctx;
}

export function moveTo(ctx, x, y) {
  ctx.moveTo(x, y);
  return ctx;
}

export function lineTo(ctx, x, y) {
  ctx.lineTo(x, y);
  return ctx;
}

export function stroke(ctx) {
  ctx.stroke();
  return ctx;
}
