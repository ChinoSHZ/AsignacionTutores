# instalar la librería: 
# pip install pandas openpyxl

import os
import pandas as pd
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from datetime import datetime

def separar_nombre_completo(nombre_completo, conectores=None):
    if conectores is None:
        conectores = ["DE", "LOS", "LA", "LAS", "DEL", "SAN", "SANTA", "Y", "EL", "E", "SANTO"]
    
    if pd.isna(nombre_completo):
        return "", "", ""
        
    palabras = str(nombre_completo).strip().split()
    if not palabras:
        return "", "", ""
    
    paterno_words = []
    idx = 0
    if idx < len(palabras):
        paterno_words.append(palabras[idx])
        idx += 1
    
    while idx < len(palabras):
        if palabras[idx].upper() in conectores:
            paterno_words.append(palabras[idx])
            idx += 1
        else:
            if len(paterno_words) > 1 and paterno_words[-1].upper() in conectores:
                paterno_words.append(palabras[idx])
                idx += 1
                break
            else:
                break
                
    materno_words = []
    if idx < len(palabras):
        materno_words.append(palabras[idx])
        idx += 1
        
    while idx < len(palabras):
        if palabras[idx].upper() in conectores:
            materno_words.append(palabras[idx])
            idx += 1
        else:
            if len(materno_words) > 1 and materno_words[-1].upper() in conectores:
                materno_words.append(palabras[idx])
                idx += 1
                break
            else:
                break
                
    nombre_words = palabras[idx:]
    
    apellido_paterno = " ".join(paterno_words)
    apellido_materno = " ".join(materno_words)
    nombres = " ".join(nombre_words)
    
    return apellido_paterno, apellido_materno, nombres

def procesar_formato_completo(ruta_entrada, ruta_salida):
    df = pd.read_excel(ruta_entrada)
    df.columns = [str(col).strip() for col in df.columns]

    col_pe = next((c for c in df.columns if c.upper() in ["P.E.", "PE", "LICENCIATURA"]), None)
    col_cuenta = next((c for c in df.columns if "CUENTA" in c.upper()), None)
    col_alumno = next((c for c in df.columns if "ALUMNO" in c.upper() or "NOMBRE_COMPLETO" in c.upper()), None)
    col_ingreso = next((c for c in df.columns if "ING" in c.upper() or "PERIODO" in c.upper()), None)
    col_tutor = next((c for c in df.columns if "TUTOR" in c.upper()), None)

    if not all([col_pe, col_cuenta, col_alumno, col_ingreso, col_tutor]):
        raise ValueError(
            "No se encontraron las columnas requeridas (P.E., Cuenta, Alumno, Ingreso, Tutor)."
        )

    registros_finales = []

    for _, fila in df.iterrows():
        ap_pat_alu, ap_mat_alu, nom_alu = separar_nombre_completo(fila[col_alumno])
        ap_pat_tut, ap_mat_tut, nom_tut = separar_nombre_completo(fila[col_tutor])

        registro = {
            "Licenciatura": fila[col_pe],
            "Número de cuenta": fila[col_cuenta],

            # Tutorado
            "Apellido Paterno del tutorado": ap_pat_alu,
            "Apellido Materno del tutorado": ap_mat_alu,
            "Nombre del tutorado": nom_alu,

            "Periodo de ingreso": fila[col_ingreso],

            # Tutor
            "Apellido Paterno del tutor": ap_pat_tut,
            "Apellido Materno del tutor": ap_mat_tut,
            "Nombre del tutor": nom_tut
        }

        registros_finales.append(registro)

    df_resultado = pd.DataFrame(registros_finales)

    # Orden deseado de las columnas en el archivo final
    columnas_ordenadas = [
        "Licenciatura",
        "Número de cuenta",
        "Apellido Paterno del tutorado",
        "Apellido Materno del tutorado",
        "Nombre del tutorado",
        "Periodo de ingreso",
        "Apellido Paterno del tutor",
        "Apellido Materno del tutor",
        "Nombre del tutor"
    ]

    df_resultado = df_resultado[columnas_ordenadas]
    df_resultado.to_excel(ruta_salida, index=False)

def procesar_solo_nombres(ruta_entrada, ruta_salida):
    df = pd.read_excel(ruta_entrada)
    df.columns = [str(col).strip() for col in df.columns]
    
    col_nombre = df.columns[0]
    for c in df.columns:
        if "NOMBRE" in c.upper() or "COMPLETO" in c.upper():
            col_nombre = c
            break
            
    registros_finales = []
    for _, fila in df.iterrows():
        ap_pat, ap_mat, nom = separar_nombre_completo(fila[col_nombre])
        registros_finales.append({
            "Apellido Paterno": ap_pat,
            "Apellido Materno": ap_mat,
            "Nombre": nom
        })
        
    df_resultado = pd.DataFrame(registros_finales)
    df_resultado.to_excel(ruta_salida, index=False)

class AppUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Transformador de Archivos Excel")
        self.root.geometry("600x450")
        self.root.configure(bg="#f4f6f9")
        self.root.resizable(False, False)

        self.ruta_archivo_entrada = None
        self.modo = tk.StringVar(value="1")
        self.nombre_salida = tk.StringVar()

        self.actualizar_nombre_defecto()
        self.modo.trace_add("write", lambda *args: self.actualizar_nombre_defecto())

        self.construir_interfaz()

    def actualizar_nombre_defecto(self):
        fecha_hora = datetime.now().strftime("%Y%m%d_%H%M%S")
        if self.modo.get() == "1":
            self.nombre_salida.set(f"FormatoRegistroHistorico_{fecha_hora}")
        else:
            self.nombre_salida.set(f"FormatoNombreApellidos_{fecha_hora}")

    def construir_interfaz(self):
        estilo_titulo = ("Segoe UI", 16, "bold")
        estilo_texto = ("Segoe UI", 11)
        
        # Marco Principal
        main_frame = tk.Frame(self.root, bg="#f4f6f9", padx=20, pady=20)
        main_frame.pack(fill="both", expand=True)

        # Título
        tk.Label(main_frame, text="Generación de Excel para Sistema de Tutoría", font=estilo_titulo, bg="#f4f6f9", fg="#2c3e50").pack(anchor="w", pady=(0, 15))

        # Sección: Selección de Modo
        frame_modo = tk.LabelFrame(main_frame, text=" 1. Tipo de Operación ", font=estilo_texto, bg="#ffffff", fg="#34495e", padx=10, pady=10)
        frame_modo.pack(fill="x", pady=(0, 15))

        tk.Radiobutton(frame_modo, text="Formato Completo del Histórico de SITA (9 columnas)", variable=self.modo, value="1", font=estilo_texto, bg="#ffffff", activebackground="#ffffff").pack(anchor="w", pady=2)
        tk.Radiobutton(frame_modo, text="Solo columna con Nombre Completo (Paterno, Materno y Nombre)", variable=self.modo, value="2", font=estilo_texto, bg="#ffffff", activebackground="#ffffff").pack(anchor="w", pady=2)

        # Sección: Subida de Archivo
        frame_subida = tk.LabelFrame(main_frame, text=" 2. Cargar Archivo Original ", font=estilo_texto, bg="#ffffff", fg="#34495e", padx=10, pady=10)
        frame_subida.pack(fill="x", pady=(0, 15))

        btn_subir = tk.Button(frame_subida, text="Subir Archivo Excel", command=self.seleccionar_archivo, bg="#007bff", fg="white", font=("Segoe UI", 10, "bold"), relief="flat", padx=15, pady=5, cursor="hand2")
        btn_subir.pack(side="left", padx=(0, 15))

        self.lbl_archivo_subido = tk.Label(frame_subida, text="", font=("Segoe UI", 10, "italic"), bg="#ffffff", fg="#28a745")
        self.lbl_archivo_subido.pack(side="left")

        # Sección: Descarga
        frame_descarga = tk.LabelFrame(main_frame, text=" 3. Generar y Descargar ", font=estilo_texto, bg="#ffffff", fg="#34495e", padx=10, pady=10)
        frame_descarga.pack(fill="x")

        tk.Label(frame_descarga, text="Nombre del archivo final (sin extensión):", font=("Segoe UI", 10), bg="#ffffff").pack(anchor="w", pady=(0, 5))
        
        entry_nombre = tk.Entry(frame_descarga, textvariable=self.nombre_salida, font=estilo_texto, width=45, relief="solid")
        entry_nombre.pack(anchor="w", pady=(0, 15))

        btn_descargar = tk.Button(frame_descarga, text="Procesar y Descargar", command=self.ejecutar_procesamiento, bg="#28a745", fg="white", font=("Segoe UI", 11, "bold"), relief="flat", padx=20, pady=8, cursor="hand2")
        btn_descargar.pack(anchor="center")

    def seleccionar_archivo(self):
        ruta = filedialog.askopenfilename(filetypes=[("Archivos de Excel", "*.xlsx *.xls")])
        if ruta:
            self.ruta_archivo_entrada = ruta
            nombre_archivo = os.path.basename(ruta)
            self.lbl_archivo_subido.config(text=f"✓ Archivo cargado: {nombre_archivo}")

    def ejecutar_procesamiento(self):
        if not self.ruta_archivo_entrada:
            messagebox.showwarning("Advertencia", "Debe subir un archivo Excel primero.")
            return

        nombre_sugerido = self.nombre_salida.get().strip()
        if not nombre_sugerido:
            self.actualizar_nombre_defecto()
            nombre_sugerido = self.nombre_salida.get()

        if not nombre_sugerido.lower().endswith(".xlsx"):
            nombre_sugerido += ".xlsx"

        ruta_salida = filedialog.asksaveasfilename(
            initialfile=nombre_sugerido,
            defaultextension=".xlsx",
            filetypes=[("Archivos de Excel", "*.xlsx")]
        )
        
        if not ruta_salida:
            return
            
        try:
            if self.modo.get() == "1":
                procesar_formato_completo(self.ruta_archivo_entrada, ruta_salida)
            else:
                procesar_solo_nombres(self.ruta_archivo_entrada, ruta_salida)
                
            messagebox.showinfo("Éxito", f"Proceso completado correctamente.\nArchivo guardado en:\n{ruta_salida}")
            
            # Resetear la interfaz tras el éxito
            self.ruta_archivo_entrada = None
            self.lbl_archivo_subido.config(text="")
            self.actualizar_nombre_defecto()
            
        except Exception as e:
            messagebox.showerror("Error", f"Ocurrió un error al procesar el archivo:\n{str(e)}")

if __name__ == "__main__":
    root = tk.Tk()
    app = AppUI(root)
    root.mainloop()