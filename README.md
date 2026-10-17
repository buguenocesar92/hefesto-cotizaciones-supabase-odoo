# Hefesto Cotizaciones

Aplicación privada para propuestas comerciales: clientes editables, catálogo editable, cotizaciones con copia de precios y datos, descuentos por línea, impuesto configurable, vigencia, duplicación, aceptación manual, tareas y cobros.

Documento imprimible: botón Imprimir / PDF, elegir Guardar como PDF en el navegador. No es documento tributario.

[Guía completa de instalación y migración](docs/INSTALACION.md).

Incluye código, Docker/Coolify, SQLite/Supabase, migraciones, importador/exportador, preparación CSV Odoo y pruebas. El sitio utiliza D1; la distribución portable usa acceso propio sin ChatGPT. No incluye secretos ni datos reales.

## Verificar
Node 24: `node --test tests/*.test.mjs`. El package.json raíz es de Sites. Para compilar el cliente portable, en una copia separada reemplaza package.json con portable/package.json, instala dependencias y ejecuta `npm run build`. Docker realiza ese proceso. portable/dist incluye el cliente compilado.

## Comercialización
Una instancia por empresa, con instalación, personalización, carga de catálogo y soporte mensual. Esta versión no automatiza el cobro de suscripciones a tus clientes.
