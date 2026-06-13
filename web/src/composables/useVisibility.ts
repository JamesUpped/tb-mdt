import { ref, onMounted, onUnmounted } from 'vue'
import { fetchNui } from './fetchNui'

/**
 * Manages MDT visibility state and ESC-to-close.
 */
export function useVisibility() {
  const isVisible = ref(false)

  function show() {
    isVisible.value = true
  }

  function hide() {
    isVisible.value = false
    fetchNui('close')
  }

  function onKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape' && isVisible.value) {
      hide()
    }
  }

  onMounted(() => document.addEventListener('keydown', onKeyDown))
  onUnmounted(() => document.removeEventListener('keydown', onKeyDown))

  return { isVisible, show, hide }
}
