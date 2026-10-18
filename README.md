# Hefesto Cotizaciones

Aplicación privada para propuestas comerciales: clientes editables, catálogo editable, cotizaciones con copia de precios y datos, descuentos por línea, impuesto configurable, vigencia, duplicación, aceptación manual, tareas y cobros.

Documento imprimible: botón Imprimir / PDF, elegir Guardar como PDF en el navegador. No es documento tributario.

[Guía completa de instalación y migración](docs/INSTALACION.md).

Incluye código, Docker/Coolify, SQLite/Supabase, migraciones, importador/exportador, preparación CSV Odoo y pruebas. El sitio utiliza D1; la distribución portable usa acceso propio sin ChatGPT. No incluye secretos ni datos reales.

## Verificar
Node 24: `node --test tests/*.test.mjs`. El package.json raíz es de Sites. Para compilar el cliente portable, en una copia separada reemplaza package.json con portable/package.json, instala dependencias y ejecuta `npm run build`. Docker realiza ese proceso. portable/dist incluye el cliente compilado.

## Comercialización
Una instancia por empresa, con instalación, personalización, carga de catálogo y soporte mensual. Esta versión no automatiza el cobro de suscripciones a tus clientes.

## Despliegue en Coolify (MVP Hefesto)
1. En el proyecto Supabase asociado, abre SQL Editor y ejecuta `supabase/migrations/202610130001_hefesto_taller.sql` una sola vez (crea `hefesto_cotizaciones_states` y `hefesto_cotizaciones_sessions`).
2. En Coolify crea el recurso a partir de este repositorio, rama `coolify`, build pack Docker Compose.
3. Selecciona `compose.supabase.yaml` como compose file y asigna el dominio al servicio `taller` (puerto interno 3000). Coolify coloca Traefik delante y resuelve TLS.
4. Variables de entorno obligatorias (obligatorias marcadas con `?` en el compose): `ADMIN_PASSWORD` (16+ caracteres), `PUBLIC_ORIGIN` (https del dominio de Coolify), `SUPABASE_URL` y `SUPABASE_SECRET_KEY` (clave `sb_secret_…`, nunca `anon/publishable`). Opcionales: `WORKSHOP_ID` (`main` por defecto), `COOKIE_SECURE` (`true` en producción).
5. Antes del primer deploy y tras cada cambio del compose, ejecuta `bash scripts/coolify-check.sh`. Sale 0 cuando `compose.supabase.yaml` cumple el contrato (sin `ports:` ni capacidades que escapen a Traefik); la versión local con SQLite (`compose.yaml`) queda exceptuada porque está marcada como `# bootstrap:`.

No migres `supabase db push` contra la base compartida: la versión de migración `202610130001` coincide con la de otros productos Hefesto. Aplica el SQL a mano desde SQL Editor.
