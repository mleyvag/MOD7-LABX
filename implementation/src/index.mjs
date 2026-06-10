// ============================================================
// Lambda Handler — Cuentas Bancarias API
// Endpoint: GET /clientes/{clienteId}/cuentas
// ============================================================

export const handler = async (event) => {
  console.log("Event received:", JSON.stringify(event, null, 2));

  const clienteId = event.pathParameters?.clienteId;
  const httpMethod = event.httpMethod;

  // ── Headers CORS ──
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, x-api-key, Idempotency-Key",
  };

  // ── Validar clienteId ──
  if (!clienteId) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({
        type: "https://api.banco.com/errors/validation",
        title: "Parámetro requerido faltante",
        status: 400,
        detail: "El parámetro 'clienteId' es obligatorio.",
        instance: event.path,
      }),
    };
  }

  // ── GET /clientes/{clienteId}/cuentas ──
  if (httpMethod === "GET") {
    // Datos simulados (en producción vendrían de DynamoDB o RDS)
    const cuentas = {
      CLI001: [
        {
          numeroCuenta: "1234567890",
          tipo: "AHORROS",
          moneda: "PEN",
          titular: "Miguel Leyva",
          saldo: 5000.0,
        },
        {
          numeroCuenta: "0987654321",
          tipo: "CORRIENTE",
          moneda: "USD",
          titular: "Miguel Leyva",
          saldo: 1200.5,
        },
      ],
      CLI002: [
        {
          numeroCuenta: "1111222233",
          tipo: "AHORROS",
          moneda: "PEN",
          titular: "María García",
          saldo: 15000.0,
        },
      ],
    };

    const clienteCuentas = cuentas[clienteId];

    if (!clienteCuentas) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({
          type: "https://api.banco.com/errors/not-found",
          title: "Cliente no encontrado",
          status: 404,
          detail: `No se encontró el cliente con ID '${clienteId}'.`,
          instance: event.path,
        }),
      };
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        clienteId: clienteId,
        cuentas: clienteCuentas,
      }),
    };
  }

  // ── POST /clientes/{clienteId}/cuentas (para Lab Propuesto) ──
  // TODO: Implementar en el laboratorio propuesto
  // if (httpMethod === "POST") { ... }

  // ── Método no soportado ──
  return {
    statusCode: 405,
    headers,
    body: JSON.stringify({
      type: "https://api.banco.com/errors/method-not-allowed",
      title: "Método no permitido",
      status: 405,
      detail: `El método ${httpMethod} no está soportado para este recurso.`,
      instance: event.path,
    }),
  };
};
