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

## 🚀 Instalación y Uso

### Configuración de GitHub
1. Crea un repositorio en GitHub (ej: `Anima-lib`) para tus libros.
2. Genera un **Personal Access Token (PAT)** con permisos de `repo`.
3. Sube tus archivos `.pdf` o `.epub` al repositorio.

### Configuración de la App
Al iniciar Anima por primera vez, ingresa:
- **GitHub PAT**: Tu token generado.
- **Owner**: Tu nombre de usuario de GitHub.
- **Repo Name**: El nombre de tu repositorio de libros.

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
