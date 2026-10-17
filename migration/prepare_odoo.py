"""Exportación de preparación; no escribe a Odoo ni crea asientos."""
import csv,json,sys
from pathlib import Path
if len(sys.argv)!=3:raise SystemExit('Uso: python3 migration/prepare_odoo.py respaldo.json carpeta-salida')
p=json.loads(Path(sys.argv[1]).read_text());s=p.get('state',p)
if s.get('format')!='hefesto-cotizaciones':raise SystemExit('Formato incompatible')
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
def save(name,columns,rows):
 with (out/name).open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.writer(f);w.writerow(columns);w.writerows(rows)
save('01_contactos.csv',['ID externo','Nombre','Contacto','RUT referencia','Correo','Teléfono','Dirección'],[['hefesto_customer_'+c['id'],c['name'],c['contact'],c['rut'],c['email'],c['phone'],c['address']] for c in s['customers']])
save('02_catalogo.csv',['ID externo','Nombre','Código','Categoría','Unidad referencia','Precio neto CLP','Afecto impuesto','Activo'],[['hefesto_product_'+p['id'],p['name'],p['sku'],p['category'],p['unit'],p['price'],p['taxable'],p['active']] for p in s['catalog']])
save('03_cotizaciones_revision.csv',['ID externo','Cliente referencia','Título','Fecha','Vigencia','Estado origen','Impuesto porcentaje','Condiciones'],[['hefesto_quote_'+q['id'],'hefesto_customer_'+q['customerId'],q['title'],q['date'],q['validUntil'],q['status'],q['taxRate'],q['terms']] for q in s['quotes']])
save('04_lineas_revision.csv',['ID externo','Cotización referencia','Producto referencia','Nombre fijado','Descripción','Unidad','Cantidad','Precio neto CLP','Descuento porcentaje','Afecto impuesto'],[['hefesto_line_'+l['id'],'hefesto_quote_'+q['id'],'hefesto_product_'+l['productId'],l['name'],l['description'],l['unit'],l['qty'],l['price'],l['discount'],l['taxable']] for q in s['quotes'] for l in q['lines']])
save('05_cobros_conciliacion.csv',['ID','Cotización referencia','Fecha','Monto CLP','Método','Referencia'],[[p['id'],'hefesto_quote_'+q['id'],p['date'],p['amount'],p['method'],p['reference']] for q in s['quotes'] for p in q['payments']])
save('06_seguimientos_revision.csv',['ID','Cotización referencia','Título','Vencimiento','Estado','Notas'],[[t['id'],'hefesto_quote_'+t['quoteId'],t['title'],t['due'],t['status'],t['notes']] for t in s['tasks']])
(out/'respaldo_completo.json').write_text(json.dumps(s,ensure_ascii=False,indent=2))
(out/'LEEME.txt').write_text('CSV de preparación, no importación automática. Mapear columnas, impuestos, unidades, relaciones y estados según versión y módulos Odoo. Importar primero contactos y catálogo. Cotizaciones y líneas requieren adaptación conjunta. Cobros solo para conciliación; no crean asientos. Datos históricos de cliente/emisor, aceptación e historial permanecen en JSON. Probar en base de ensayo y comparar totales y redondeo. No incluye addon.\n')
print('Exportación preparada:',out)
