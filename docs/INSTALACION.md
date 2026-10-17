# Hefesto Cotizaciones — instalación y traspaso

## Supabase y Coolify
1. Crea o selecciona un proyecto Supabase.
2. Ejecuta `supabase/migrations/202610130001_hefesto_taller.sql`. El nombre heredado no afecta las tablas exclusivas: hefesto_cotizaciones_states y hefesto_cotizaciones_sessions.
3. Copia `.env.example` a `.env`. Completa SUPABASE_URL, SUPABASE_SECRET_KEY (sb_secret o service_role), WORKSHOP_ID, ADMIN_PASSWORD (16 caracteres mínimo), PUBLIC_ORIGIN (dominio HTTPS), COOKIE_SECURE=true.
4. Ejecuta `docker compose -f compose.supabase.yaml up -d --build`. En Coolify selecciona ese Compose y asigna dominio al puerto interno 3000.
5. Accede con la contraseña de administrador. Clave Supabase exclusivamente en el servidor.

El servicio Compose conserva el nombre técnico `taller` por compatibilidad del adaptador; las tablas son propias de Cotizaciones. Si instalas varios productos en un servidor cambia el puerto de host 3080 por uno distinto para cada aplicación y asigna dominios separados.

## SQLite
`docker compose -f compose.yaml up -d --build`. Volumen persistente. En local PUBLIC_ORIGIN=http://localhost:3080 y COOKIE_SECURE=false. En producción HTTPS y cookie segura. La instalación portable empieza sin clientes, catálogo ni cotizaciones; conserva ajustes predeterminados que debes revisar.

## Migrar desde el sitio
Exporta JSON en Portabilidad. El ZIP contiene código y demo, no datos reales.

```
docker compose -f compose.supabase.yaml cp hefesto-cotizaciones.json taller:/data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs validate /data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs import /data/import.json
```

Rechaza sobrescribir instancias con registros. Usa WORKSHOP_ID nuevo o volumen nuevo. Pausa operaciones durante migración. Conserva IDs, cotizaciones, datos históricos, pagos e historial. Exportar: ejecutar `node portable/tools/transfer.mjs export /data/respaldo.json` dentro del servicio y copiar fuera con docker compose cp. Mantén respaldos protegidos independientes.

## Preparación Odoo
`python3 migration/prepare_odoo.py hefesto-cotizaciones.json salida-odoo`

CSV de contactos, catálogo, propuestas, líneas, cobros y seguimientos, más JSON íntegro. Requiere mapear impuestos, unidades, relaciones, estados y campos según módulos y versión destino. Cobros solo para conciliación: no crean asientos. No hay addon ni sincronización. Prueba primero en una base de ensayo y compara totales y redondeo.

## Operación
1. Configurar emisor, impuesto, vigencia y condiciones.
2. Crear clientes y catálogo con precios netos CLP.
3. Crear borrador, agregar líneas y editar cantidad, precio, descuento o descripción.
4. Revisar documento e imprimir/guardar PDF. Entregar fuera de la app y registrar entrega con referencia en Gestión.
5. Registrar aceptación con nombre y evidencia de referencia, o rechazo. Crear tareas de seguimiento.
6. Registrar cobros solo de propuestas aceptadas; no exceder saldo. Para anular una aceptada con dinero recibido, registrar primero devolución real con referencia.

La aceptación es un registro administrativo, no una firma electrónica. Datos de cliente, emisor y líneas quedan copiados en cada propuesta. Editar catálogo o cliente no cambia cotizaciones anteriores. Guardar datos de un borrador actualiza su copia de emisor/cliente. Una propuesta enviada no se edita: duplicar crea un borrador con número nuevo, sin pagos ni aceptación. La duplicación conserva contenido y precios anteriores para revisión.

IVA/impuesto configurable, entero de 0–100%; inicialmente 19%. Cálculo por línea: cantidad × precio, descuento porcentual redondeado a peso, impuesto redondeado a peso sobre neto afecto. Cantidades enteras. Revisar aplicabilidad del impuesto y configuración comercial antes de emitir propuestas. No determina tratamiento tributario ni valida RUT ante fuentes externas. Número de cotización correlativo interno, no folio fiscal.

## Alcance y verificación
- Administración privada única; sin roles comerciales individuales, portal de clientes ni múltiples empresas dentro de una instancia.
- Sin envío de correo/WhatsApp, firma electrónica, pasarela, factura/boleta/SII o sincronización Odoo.
- Catálogo sin inventario. Cotizaciones en CLP; sin tipos de cambio, cuotas automáticas o facturación recurrente.
- Tareas y entregas manuales; no hay notificaciones en segundo plano.
- Supabase almacena un JSON por instancia con sesiones y RLS, clave solo servidor. No usa Supabase Auth ni tablas normalizadas por entidad.
- API GET/POST /api/service con revisión para evitar sobrescritura concurrente.
- Siete pruebas automáticas aprobadas, tipos y builds verificados. Docker y Supabase real requieren prueba en destino. QA visual y paginación PDF en navegador pendientes por falta de control de navegador en este entorno.
