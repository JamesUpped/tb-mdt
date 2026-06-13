<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60" @click.self="$emit('close')">
    <div class="w-[760px] max-h-[85vh] flex flex-col rounded-xl bg-card border border-border shadow-2xl">
      <!-- Header -->
      <div class="flex items-center justify-between px-5 py-4 border-b border-border">
        <div>
          <h2 class="text-base font-semibold text-foreground">Process Charges</h2>
          <p class="text-xs text-muted-foreground">{{ citizenName }} · {{ citizenid }}</p>
        </div>
        <button class="text-muted-foreground hover:text-foreground transition-colors" @click="$emit('close')">
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="flex flex-1 min-h-0">
        <!-- Charge picker -->
        <div class="w-1/2 border-r border-border flex flex-col">
          <div class="flex gap-1 p-3 border-b border-border">
            <button
              v-for="(label, cat) in categories"
              :key="cat"
              class="text-xs px-3 py-1.5 rounded-lg transition-colors capitalize"
              :class="activeCategory === cat ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
              @click="activeCategory = cat"
            >{{ label }}</button>
          </div>
          <div class="flex-1 overflow-auto p-3 space-y-1.5">
            <button
              v-for="charge in penalCode[activeCategory] ?? []"
              :key="charge.id"
              class="w-full flex items-center gap-3 p-2.5 rounded-lg border text-left transition-colors"
              :class="isSelected(charge.id)
                ? 'bg-primary/10 border-primary/40'
                : 'bg-secondary/40 border-border/50 hover:border-primary/30'"
              @click="toggleCharge(charge)"
            >
              <div
                class="w-4 h-4 rounded border flex items-center justify-center shrink-0"
                :class="isSelected(charge.id) ? 'bg-primary border-primary' : 'border-muted-foreground/40'"
              >
                <Check v-if="isSelected(charge.id)" class="w-3 h-3 text-primary-foreground" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-medium text-foreground">{{ charge.id }} · {{ charge.title }}</p>
                <p class="text-[10px] text-muted-foreground">
                  ${{ charge.fineMin.toLocaleString() }}–${{ charge.fineMax.toLocaleString() }}
                  <template v-if="charge.jailMax > 0"> · {{ charge.jailMin }}–{{ charge.jailMax }} min</template>
                  <template v-if="charge.points > 0"> · {{ charge.points }} pts</template>
                </p>
              </div>
            </button>
          </div>
        </div>

        <!-- Selected charges with sliders -->
        <div class="w-1/2 flex flex-col">
          <div class="flex-1 overflow-auto p-3 space-y-3">
            <div v-if="selected.length === 0" class="text-center py-10">
              <Scale class="w-10 h-10 text-muted-foreground/30 mx-auto mb-2" />
              <p class="text-xs text-muted-foreground">Select charges from the penal code</p>
            </div>

            <div v-for="charge in selected" :key="charge.id" class="p-3 rounded-lg bg-secondary/40 border border-border/50 space-y-2">
              <div class="flex items-center justify-between">
                <p class="text-xs font-medium text-foreground">{{ charge.id }} · {{ charge.title }}</p>
                <button class="text-muted-foreground hover:text-destructive-foreground transition-colors" @click="removeCharge(charge.id)">
                  <X class="w-3.5 h-3.5" />
                </button>
              </div>

              <!-- Fine slider -->
              <div v-if="charge.fineMax > charge.fineMin" class="space-y-1">
                <div class="flex justify-between text-[10px] text-muted-foreground">
                  <span>Fine</span><span class="text-foreground font-medium">${{ charge.fine.toLocaleString() }}</span>
                </div>
                <input
                  v-model.number="charge.fine"
                  type="range" :min="charge.fineMin" :max="charge.fineMax" :step="50"
                  class="w-full accent-blue-500 h-1.5"
                />
              </div>
              <p v-else class="text-[10px] text-muted-foreground">Fine: <span class="text-foreground font-medium">${{ charge.fine.toLocaleString() }}</span></p>

              <!-- Jail slider -->
              <div v-if="charge.jailMax > 0" class="space-y-1">
                <div class="flex justify-between text-[10px] text-muted-foreground">
                  <span>Sentence</span><span class="text-foreground font-medium">{{ charge.jail }} min</span>
                </div>
                <input
                  v-model.number="charge.jail"
                  type="range" :min="charge.jailMin" :max="charge.jailMax" :step="1"
                  class="w-full accent-red-500 h-1.5"
                />
              </div>
            </div>
          </div>

          <!-- Totals + process -->
          <div class="border-t border-border p-4 space-y-3">
            <div class="grid grid-cols-3 gap-2 text-center">
              <div class="rounded-lg bg-secondary/40 py-2">
                <p class="text-sm font-semibold text-foreground">${{ totalFine.toLocaleString() }}</p>
                <p class="text-[10px] text-muted-foreground">Total fine</p>
              </div>
              <div class="rounded-lg bg-secondary/40 py-2">
                <p class="text-sm font-semibold text-foreground">{{ totalJail }} min</p>
                <p class="text-[10px] text-muted-foreground">Total sentence</p>
              </div>
              <div class="rounded-lg bg-secondary/40 py-2">
                <p class="text-sm font-semibold text-foreground">{{ totalPoints }}</p>
                <p class="text-[10px] text-muted-foreground">License pts</p>
              </div>
            </div>
            <button
              class="w-full text-sm bg-primary text-primary-foreground py-2.5 rounded-lg font-medium hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="selected.length === 0 || processing"
              @click="process"
            >{{ processing ? 'Processing…' : 'Process Charges' }}</button>
            <p v-if="error" class="text-xs text-red-400 text-center">{{ error }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed } from 'vue'
import { X, Check, Scale } from 'lucide-vue-next'
import { useAppStore } from '@/stores/appStore'
import { useCitizenStore } from '@/stores/citizenStore'
import type { PenalCharge, SelectedCharge } from '@/types'

const props = defineProps<{
  citizenid: string
  citizenName: string
  incidentId?: number
}>()

const emit = defineEmits<{
  close: []
  processed: [result: { totalFine: number; totalJail: number; finePaid: boolean }]
}>()

const appStore = useAppStore()
const citizenStore = useCitizenStore()

const penalCode = computed(() => appStore.config?.penalCode ?? {})
const categories: Record<string, string> = {
  traffic: 'Traffic',
  misdemeanor: 'Misdemeanor',
  felony: 'Felony',
}

const activeCategory = ref('traffic')
const selected = ref<SelectedCharge[]>([])
const processing = ref(false)
const error = ref('')

const totalFine = computed(() => selected.value.reduce((sum, c) => sum + c.fine, 0))
const totalJail = computed(() => selected.value.reduce((sum, c) => sum + c.jail, 0))
const totalPoints = computed(() => selected.value.reduce((sum, c) => sum + c.points, 0))

function isSelected(id: string) {
  return selected.value.some(c => c.id === id)
}

function toggleCharge(charge: PenalCharge) {
  if (isSelected(charge.id)) {
    removeCharge(charge.id)
    return
  }
  selected.value.push({
    id: charge.id,
    title: charge.title,
    category: activeCategory.value,
    fine: charge.fineMin,
    jail: charge.jailMin,
    points: charge.points,
    fineMin: charge.fineMin,
    fineMax: charge.fineMax,
    jailMin: charge.jailMin,
    jailMax: charge.jailMax,
  })
}

function removeCharge(id: string) {
  selected.value = selected.value.filter(c => c.id !== id)
}

async function process() {
  if (selected.value.length === 0 || processing.value) return
  processing.value = true
  error.value = ''
  try {
    const result = await citizenStore.processCharges(props.citizenid, props.citizenName, selected.value, props.incidentId)
    if (result.success) {
      emit('processed', {
        totalFine: result.totalFine ?? 0,
        totalJail: result.totalJail ?? 0,
        finePaid: result.finePaid ?? false,
      })
      emit('close')
    } else {
      error.value = result.error ?? 'Failed to process charges'
    }
  } finally {
    processing.value = false
  }
}
</script>
