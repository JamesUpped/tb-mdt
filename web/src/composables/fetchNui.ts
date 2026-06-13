import api from '@/api/axios'

/**
 * Call a RegisterNUICallback on the Lua client.
 * @param eventName - The callback name registered in client/main.lua
 * @param data - Payload to send
 * @returns The response data from the Lua callback
 */
export async function fetchNui<T = unknown>(eventName: string, data: Record<string, unknown> = {}): Promise<T> {
  const res = await api.post<T>(eventName, data)
  return res.data
}
