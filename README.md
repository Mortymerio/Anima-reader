# 🌑 Anima Reader
> Lector minimalista de alto contraste optimizado para dispositivos E-ink.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![GitHub API](https://img.shields.io/badge/GitHub_API-181717?style=for-the-badge&logo=github&logoColor=white)

Anima es un lector de libros electrónicos diseñado específicamente para pantallas de tinta electrónica (E-ink). Utiliza la infraestructura de **GitHub** como nube personal para gestionar tu biblioteca y sincronizar tu progreso de lectura entre dispositivos.

## ✨ Características Principales

- **Optimización E-ink**: Interfaz en blanco y negro puro (#000000 y #FFFFFF).
- **Refresco Anti-Ghosting**: Flash de limpieza de pantalla automático cada 10 cambios de página.
- **Sin Animaciones**: Transiciones instantáneas para evitar el parpadeo grisáceo.
- **Sincronización en la Nube**: Progreso guardado automáticamente en un archivo `sync.json` en tu propio repositorio de GitHub.
- **Multi-formato con Reflow**: 
  - **PDF**: Extracción de texto y ajuste dinámico al ancho de pantalla.
  - **EPUB**: Soporte nativo para lectura fluida.
- **Personalización**: Selector de tamaño de fuente en tiempo real con memoria persistente.

## 🚀 Configuración de tu Biblioteca (Paso a Paso)

Para utilizar Anima y sincronizar tu progreso, necesitas configurar un repositorio de GitHub que servirá como tu biblioteca personal en la nube. Sigue estos sencillos pasos:

### Paso 1: Crear el Repositorio de Libros
1. Inicia sesión en [GitHub](https://github.com). Si no tienes una cuenta, regístrate (es 100% gratis).
2. En la esquina superior derecha, haz clic en el botón **`+`** y selecciona **New repository** (Nuevo repositorio).
3. Configura los siguientes campos:
   - **Repository name**: Dale un nombre a tu biblioteca (ej: `mis-libros` o `Anima-library`).
   - **Public/Private**: Marca el repositorio como **Private** (Privado) para proteger los derechos de autor de tus libros personales.
   - **Initialize this repository with**: Marca la casilla **Add a README file**. Esto es obligatorio para que el repositorio se inicialice correctamente y la app pueda comunicarse con él.
4. Haz clic en **Create repository**.

### Paso 2: Generar tu Personal Access Token (PAT)
El PAT es una "contraseña especial" que permite a Anima acceder a tus libros y guardar tu progreso de forma segura.
1. Haz clic en tu foto de perfil en la esquina superior derecha de GitHub y ve a **Settings** (Configuración).
2. En la barra lateral izquierda, baja hasta el final y haz clic en **<> Developer settings** (Configuración de desarrollador).
3. Selecciona **Personal access tokens** -> **Tokens (classic)**.
4. Haz clic en **Generate new token** -> **Generate new token (classic)**.
5. Configura el token:
   - **Note**: Escribe un nombre descriptivo, por ejemplo: `Anima Reader E-ink`.
   - **Expiration**: Selecciona la duración que prefieras (te sugerimos *No expiration* para que no expire nunca).
   - **Scopes (Permisos)**: Marca únicamente la casilla **`repo`** (esto otorgará permisos de lectura/escritura para gestionar tus libros y progreso en repositorios privados).
6. Ve al final de la página y haz clic en **Generate token**.
7. ⚠️ **IMPORTANTE**: Copia el token que aparece en pantalla inmediatamente. **No podrás volver a verlo**. Guárdalo en un lugar seguro (por ejemplo, en tus notas o gestor de contraseñas) para ingresarlo en Anima.

### Paso 3: Subir tus Libros (Rutas y Paths)
Para que Anima reconozca tus libros, debes subirlos en la ubicación adecuada:
1. Entra a tu repositorio recién creado en GitHub.
2. Haz clic en el botón **Add file** -> **Upload files** (Subir archivos).
3. Arrastra tus libros en formato **`.epub`** o **`.pdf`** y suéltalos en la ventana.
4. ⚠️ **Ruta Correcta (Path)**: Asegúrate de subirlos **directamente en la raíz (root)** del repositorio (no dentro de subcarpetas como `libros/` o `documentos/`). La app busca tus títulos únicamente en la raíz del repositorio.
5. Haz clic en **Commit changes** (Confirmar cambios) al final para guardar los libros.

### Paso 4: Sincronización del Progreso (`sync.json`)
¡No necesitas crear este archivo manualmente! 
- Anima se encargará de crear y actualizar un archivo llamado **`sync.json`** en la raíz de tu repositorio de forma automática cada vez que dejes de leer por unos segundos (de forma asíncrona) o cambies de capítulo.
- Este archivo registra de manera compacta tu página y progreso exacto, permitiéndote reanudar tus lecturas en cualquier momento y dispositivo sincronizado.

### Paso 5: Configurar la App
Al iniciar Anima por primera vez en tu dispositivo, ingresa los siguientes datos:
- **GitHub PAT**: El token personal (PAT) que copiaste en el *Paso 2*.
- **Owner**: Tu nombre de usuario de GitHub.
- **Repo Name**: El nombre exacto de tu repositorio de libros (creado en el *Paso 1*).

## 🛠️ Desarrollo Local

Si deseas compilar el proyecto tú mismo:

```powershell
# Instalar dependencias
flutter pub get

# Ejecutar en Windows
flutter run -d windows

# Generar APK para Android/E-ink
flutter build apk --release
```

## 📖 Estrategia de Lectura
Anima implementa un sistema de **sub-páginas** para el texto extraído. Al tocar el lado derecho, la app bajará un bloque de texto si la página es larga; solo al llegar al final del texto saltará a la siguiente página del documento original.

---
Desarrollado con ❤️ para la comunidad de lectores digitales.
