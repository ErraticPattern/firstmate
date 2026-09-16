// Firstmate's selectable Calm working animation.
//
// The classic directional ASCII boat remains the default. The newer smooth Unicode
// swell is retained as an explicit alternative. This module owns selection and keeps
// the extension-facing animation and widget contract independent of either renderer.
import type { Component, TUI } from "@earendil-works/pi-tui";
import {
  CALM_WORKING_SHIP_TICK_MS,
  CALM_WORKING_SHIP_TICKS_PER_MOVE,
  CALM_WORKING_SHIP_WIDGET_KEY,
  createCalmWorkingShipAnimation as createClassicAnimation,
  createCalmWorkingShipWidget as createClassicWidget,
  type CalmWorkingShipAnimation,
} from "./fm-calm-working-ship-classic.ts";
import {
  createCalmWorkingShipAnimation as createSwellAnimation,
  createCalmWorkingShipWidget as createSwellWidget,
} from "./fm-calm-working-ship-swell.ts";

export {
  CALM_WORKING_SHIP_TICK_MS,
  CALM_WORKING_SHIP_TICKS_PER_MOVE,
  CALM_WORKING_SHIP_WIDGET_KEY,
  type CalmWorkingShipAnimation,
};

export type CalmWorkingAnimationStyle = "classic" | "swell";

export function createCalmWorkingShipAnimation(
  style: CalmWorkingAnimationStyle = "classic",
): CalmWorkingShipAnimation {
  return style === "swell" ? createSwellAnimation() : createClassicAnimation();
}

export function createCalmWorkingShipWidget(
  tui: TUI,
  animation: CalmWorkingShipAnimation = createCalmWorkingShipAnimation(),
  style: CalmWorkingAnimationStyle = "classic",
): Component & { dispose(): void } {
  return style === "swell"
    ? createSwellWidget(tui, animation)
    : createClassicWidget(tui, animation);
}
