# Cómo añadir un repositorio Git como submódulo dentro de otro proyecto

Cuando desarrollamos un proyecto grande, a veces necesitamos incluir otro repositorio Git dentro de nuestro código fuente. Por ejemplo, puede tratarse de una colección de diccionarios, una biblioteca de terceros, documentación compartida o cualquier otro componente que se mantenga de forma independiente.

Para estos casos, Git ofrece una característica llamada **submódulos (submodules)**, que permite incluir un repositorio dentro de otro sin copiar ni duplicar su contenido.

## ¿Qué es un submódulo?

Un submódulo es una referencia a otro repositorio Git almacenada dentro de nuestro proyecto principal. De esta forma:

* El proyecto principal mantiene una referencia a una revisión específica del repositorio externo.
* El repositorio externo puede seguir desarrollándose de manera independiente.
* No es necesario copiar archivos manualmente.
* Se facilita la actualización de dependencias.

## Estructura de ejemplo

Supongamos que tenemos el siguiente proyecto:

```
mi-proyecto/
├── src/
├── docs/
├── resources/
└── third-party/
```

Y queremos añadir un repositorio externo dentro de la carpeta `third-party`.

El resultado deseado sería:

```
mi-proyecto/
├── src/
├── docs/
├── resources/
└── third-party/
    └── mi-biblioteca/
```

## Añadir el submódulo

Para agregar el repositorio, basta con ejecutar:

```bash
git submodule add https://github.com/usuario/mi-biblioteca.git third-party/mi-biblioteca
```

Git descargará el repositorio y creará automáticamente el archivo `.gitmodules`.

## El archivo `.gitmodules`

Después de añadir el submódulo, Git genera una configuración similar a la siguiente:

```
[submodule "third-party/mi-biblioteca"]
    path = third-party/mi-biblioteca
    url = https://github.com/usuario/mi-biblioteca.git
```

Este archivo indica:

* **path**: ubicación donde se encuentra el submódulo dentro del proyecto.
* **url**: dirección del repositorio remoto.

Normalmente no es necesario editar este archivo manualmente.

## Confirmar los cambios

Una vez agregado el submódulo, debemos registrar los cambios en Git:

```bash
git add .gitmodules third-party/mi-biblioteca
git commit -m "Add submodule"
git push
```

## Clonar un proyecto que contiene submódulos

Si otra persona clona el proyecto utilizando:

```bash
git clone https://github.com/usuario/mi-proyecto.git
```

los submódulos no se descargarán automáticamente.

Para obtenerlos deberá ejecutar:

```bash
git submodule update --init --recursive
```

O bien realizar la clonación directamente con:

```bash
git clone --recursive https://github.com/usuario/mi-proyecto.git
```

## Actualizar un submódulo

Para obtener los cambios más recientes del repositorio externo:

```bash
cd third-party/mi-biblioteca

git pull origin main
```

Luego, desde el proyecto principal:

```bash
git add third-party/mi-biblioteca
git commit -m "Update submodule"
git push
```

## Eliminar un submódulo

Si ya no necesitamos el repositorio externo, podemos eliminarlo mediante:

```bash
git submodule deinit -f third-party/mi-biblioteca

git rm -f third-party/mi-biblioteca

rm -rf .git/modules/third-party/mi-biblioteca
```

Después se confirma el cambio:

```bash
git commit -m "Remove submodule"
git push
```

## Recomendaciones

Una práctica habitual consiste en almacenar todas las dependencias externas dentro de una carpeta dedicada:

```
third-party/
external/
vendor/
deps/
```

Esto facilita:

* Mantener organizado el proyecto.
* Identificar rápidamente qué componentes pertenecen a terceros.
* Simplificar la creación de paquetes para Linux, Windows y macOS.
* Reducir la posibilidad de modificar accidentalmente código externo.

---

## Ignorar el contenido sucio de los submódulos (cuando no quieres que aparezcan como "modificados")

Por defecto, cuando dentro de un submódulo hay archivos sin seguimiento (untracked) o modificaciones, Git lo reporta en el `git status` del proyecto principal como:

```
modificados:     CARA (contenido no rastreado)
modificados:     pyzo (contenido no rastreado)
```

Esto ocurre aunque el submódulo siga apuntando al mismo commit; el mensaje solo indica que hay archivos sueltos dentro de él que Git no está rastreando en ese submódulo.

### ¿Por qué ocurre?

Por ejemplo, en el repositorio de investigación:

**[https://github.com/wachin/pyqt6-packaging-research/](https://github.com/wachin/pyqt6-packaging-research/)**

se añadieron varios submódulos para estudiar cómo empaquetan aplicaciones PyQt6:

```
CARA/
CustomKnight-Creator/
dikte/
napari/
napari-packaging/
pyzo/
PyQt6-Apps/TBO/
```

Durante la investigación, agentes de IA crearon archivos dentro de esos submódulos — como `PACKAGING_STUDY.md`, `PYQT6_PACKAGING_TUTORIAL.md`, `opencode.json` — que no forman parte de los repositorios originales. Como resultado, cada vez que se ejecutaba `git status` aparecían los seis submódulos como "modificados (contenido no rastreado)", generando ruido innecesario.

### Solución: `.gitignore` no funciona

Un primer intento fue agregar las rutas de los submódulos al `.gitignore`:

```gitignore
CARA/
CustomKnight-Creator/
dikte/
napari/
napari-packaging/
pyzo/
```

Pero esto **no funcionó**. Git sigue reportando los submódulos porque **ya están rastreados como "gitlinks"** (enlaces a un commit específico). El `.gitignore` solo afecta a archivos sin seguimiento, no a directorios que Git ya está rastreando.

### Solución correcta: `ignore = dirty` en `.gitmodules`

La forma correcta y limpia de silenciar este ruido es añadir la opción `ignore = dirty` en el archivo `.gitmodules`, dentro de cada submódulo que queramos excluir:

```ini
[submodule "CARA"]
	path = CARA
	url = https://github.com/pguntermann/CARA.git
	ignore = dirty
[submodule "pyzo"]
	path = pyzo
	url = https://github.com/pyzo/pyzo.git
	ignore = dirty
# ... y así con cada submódulo
```

**Significado de `ignore = dirty`:** Git ignora los cambios dentro del submódulo (archivos modificados o sin seguimiento) y **no** los reporta en el `git status` del proyecto padre. Sin embargo, **sí** reportará si el commit al que apunta el submódulo cambia (por ejemplo, si haces `git pull` dentro del submódulo y luego actualizas la referencia en el padre). Esto es importante porque el cambio de commit sí es un cambio real en el proyecto principal.

**Otras opciones de `ignore`:**

| Valor | Efecto |
|---|---|
| `ignore = dirty` | Ignora archivos sucios y sin seguimiento, pero reporta cambios de commit. (Recomendado) |
| `ignore = untracked` | Ignora solo archivos sin seguimiento; reporta archivos modificados y cambios de commit. |
| `ignore = all` | Ignora todo: archivos sucios, sin seguimiento y cambios de commit. Úsalo solo si quieres silenciar completamente el submódulo. |

### Aplicar los cambios sin esperar al commit

Al editar `.gitmodules`, los cambios pueden no reflejarse de inmediato en el `git status` local. Para que surtan efecto al instante, ejecuta:

```bash
git submodule sync
```

Esto actualiza la configuración local de los submódulos desde el archivo `.gitmodules` modificado. Después de esto, `git status` ya no mostrará los submódulos como "modificados".

### Breve explicación del caso real

En el repositorio:

[https://github.com/wachin/pyqt6-packaging-research](https://github.com/wachin/pyqt6-packaging-research)

se usan submódulos para estudiar cómo otros proyectos empaquetan aplicaciones Python/PyQt6. Los agentes de IA que analizaron esos repositorios crearon archivos dentro de cada submódulo (informes, estudios, configuraciones). Como esos archivos no pertenecen a los repositorios originales, aparecen como "contenido no rastreado" en el `git status` del proyecto principal. La solución fue añadir `ignore = dirty` a cada submódulo en `.gitmodules`, y ejecutar `git submodule sync` para que el cambio se refleje de inmediato.

---

Dios les bendiga

---

# Referencias

**Git - Submodules Documentation**  
[https://git-scm.com/book/en/v2/Git-Tools-Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

**Git Submodule Documentation**  
[https://git-scm.com/docs/git-submodule](https://git-scm.com/docs/git-submodule)

**Git Basics - Getting a Git Repository**  
[https://git-scm.com/book/en/v2/Git-Basics-Getting-a-Git-Repository](https://git-scm.com/book/en/v2/Git-Basics-Getting-a-Git-Repository)

**GitHub Docs - Working with Submodules**  
[https://docs.github.com/en/get-started/git-basics/about-git-submodules](https://docs.github.com/en/get-started/git-basics/about-git-submodules)

**GitHub Docs - Adding a Submodule to a Repository**  
[https://docs.github.com/en/get-started/git-basics/about-git-submodules#adding-a-submodule](https://docs.github.com/en/get-started/git-basics/about-git-submodules#adding-a-submodule)

**Atlassian Git Tutorials - Git Submodule**  
[https://www.atlassian.com/git/tutorials/git-submodule](https://www.atlassian.com/git/tutorials/git-submodule)

**Pro Git Book (Second Edition)**  
[https://git-scm.com/book/en/v2](https://git-scm.com/book/en/v2)

**Git Reference Manual**  
[https://git-scm.com/docs](https://git-scm.com/docs)
