import { onMounted, onUnmounted } from 'vue'

/**
 * Listen for NUI messages from Lua's SendNUIMessage.
 * @param action - The action string to filter for
 * @param handler - Callback when this action is received
 */
export function useNuiEvent<T = unknown>(action: string, handler: (data: T) => void) {
  const listener = (event: MessageEvent) => {
    const { action: msgAction, ...rest } = event.data
    if (msgAction === action) {
      handler(rest.data !== undefined ? rest.data : rest)
    }
  }

  onMounted(() => window.addEventListener('message', listener))
  onUnmounted(() => window.removeEventListener('message', listener))
}
