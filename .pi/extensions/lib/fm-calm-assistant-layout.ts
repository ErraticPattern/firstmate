// Verified against Pi 0.81.1 and 0.82.0, which export AssistantMessageComponent with an
// updateContent method. installCalmAssistantLayout() probes that exact method and throws
// if it is missing; fm-calm.ts catches that and skips only this adapter with a diagnostic
// instead of blocking Calm or Pi.
// While Calm hides "assistant-thinking", this layout removes every thinking block from a
// shallow presentation copy, so reasoning stays hidden whatever Pi's own
// hideThinkingBlock setting says and Pi's thinking toggle cannot reveal it. Calm never
// writes that setting: each row keeps the value Pi gave it, which applies again as soon
// as Calm is off. The message itself, model context, session storage, and export
// rendering are never touched.
// installCalmThinkingToggleLabel() is a separate adapter on InteractiveMode's thinking
// toggle, verified against Pi 0.85.1: the toggle still flips and saves the captain's
// setting, but while Calm hides reasoning its confirmation says the new state applies
// once Calm is off instead of claiming thinking blocks are visible.
// ./fm-calm-visibility.ts owns which classes Calm hides.
import type { AssistantMessageComponent as PiAssistantMessageComponent } from "@earendil-works/pi-coding-agent";
import * as PiCodingAgent from "@earendil-works/pi-coding-agent";
import { calmPresentationHides } from "./fm-calm-visibility.ts";

type UpdateContentArgs = Parameters<PiAssistantMessageComponent["updateContent"]>;
type AssistantMessage = UpdateContentArgs[0];

type AssistantMessagePresentationState = {
  lastMessage?: AssistantMessage;
};

type CalmAssistantLayoutPatch = {
  hidesThinking: () => boolean;
};

type ThinkingToggleMode = {
  hideThinkingBlock: boolean;
  showStatus(message: string): void;
};

type ThinkingTogglePrototype = {
  toggleThinkingBlockVisibility(this: ThinkingToggleMode): void;
};

// Keep the introduction-version symbols stable so a compatible upgrade cannot
// double-patch a live process.
const CALM_ASSISTANT_LAYOUT_PATCH = Symbol.for(
  "firstmate:calm-assistant-layout:pi-0.81.1",
);
const CALM_THINKING_TOGGLE_PATCH = Symbol.for(
  "firstmate:calm-thinking-toggle:pi-0.85.1",
);

const hidesThinking = (): boolean => calmPresentationHides("assistant-thinking");

export function installCalmThinkingToggleLabel(): void {
  const registry = globalThis as typeof globalThis & {
    [key: symbol]: CalmAssistantLayoutPatch | undefined;
  };
  const installed = registry[CALM_THINKING_TOGGLE_PATCH];
  if (installed) {
    installed.hidesThinking = hidesThinking;
    return;
  }

  const patch: CalmAssistantLayoutPatch = { hidesThinking };
  const InteractiveMode = PiCodingAgent.InteractiveMode;
  if (typeof InteractiveMode !== "function") {
    throw new Error("Firstmate Calm requires Pi InteractiveMode");
  }
  const prototype = InteractiveMode.prototype as unknown as ThinkingTogglePrototype;
  const originalToggle = prototype.toggleThinkingBlockVisibility;
  if (typeof originalToggle !== "function") {
    throw new Error("Firstmate Calm requires Pi InteractiveMode.toggleThinkingBlockVisibility");
  }

  prototype.toggleThinkingBlockVisibility = function (): void {
    originalToggle.call(this);
    if (!patch.hidesThinking()) return;
    this.showStatus(
      `Thinking blocks: ${this.hideThinkingBlock ? "hidden" : "visible"} once Calm is off; Calm keeps reasoning hidden`,
    );
  };

  registry[CALM_THINKING_TOGGLE_PATCH] = patch;
}

export function installCalmAssistantLayout(): void {
  const registry = globalThis as typeof globalThis & {
    [key: symbol]: CalmAssistantLayoutPatch | undefined;
  };
  const installed = registry[CALM_ASSISTANT_LAYOUT_PATCH];
  if (installed) {
    installed.hidesThinking = hidesThinking;
    return;
  }

  const patch: CalmAssistantLayoutPatch = { hidesThinking };
  const AssistantMessageComponent = PiCodingAgent.AssistantMessageComponent;
  if (typeof AssistantMessageComponent !== "function") {
    throw new Error("Firstmate Calm requires Pi AssistantMessageComponent");
  }
  const originalUpdateContent = AssistantMessageComponent.prototype.updateContent;
  if (typeof originalUpdateContent !== "function") {
    throw new Error("Firstmate Calm requires Pi AssistantMessageComponent.updateContent");
  }

  AssistantMessageComponent.prototype.updateContent = function (
    ...[message, ...rest]: UpdateContentArgs
  ): void {
    const state = this as unknown as AssistantMessagePresentationState;
    const presentationMessage = patch.hidesThinking()
      ? {
          ...message,
          content: message.content.filter((block) => block.type !== "thinking"),
        }
      : message;

    originalUpdateContent.call(this, presentationMessage, ...rest);
    if (presentationMessage !== message) state.lastMessage = message;
  };

  registry[CALM_ASSISTANT_LAYOUT_PATCH] = patch;
}
