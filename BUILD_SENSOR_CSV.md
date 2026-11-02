# QBladeCE avec import CSV capteurs et visualisation couleur sur les pales

## Fonctionnalite ajoutee

- **Import de CSV capteurs** : menu `Turbine Definition > Import Data > Import Sensor CSV Data...`
  (egalement `Clear Sensor CSV Data` pour tout effacer).
- **Format CSV attendu** (separateur `,` ou `;`, en-tete obligatoire, colonnes reconnues par nom) :

  ```
  timestamp,Blade,Radius,MagZ,MagZ_std,MagZ_category,...
  2024-08-29 15:20:27.483,B,8,-7195,0,H,...
  ```

  - `timestamp` : `yyyy-MM-dd HH:mm:ss.zzz` (ou ISO)
  - `Blade` : lettre `A`/`B`/`C`... ou numero `1`/`2`/`3`... ou `Blade 1`
  - `Radius` : rayon du capteur le long de la pale, depuis le pied de pale [m]
  - `MagZ` : valeur brute du capteur
  - `MagZ_category` : `L` (Low / vert), `M` (Medium / jaune), `H` (High / rouge).
    Si la colonne est vide, la categorie est deduite de `MagZ`
    (seuils : L < 33% du max, M < 66%, H sinon).

- **Visualisation 3D** : chaque capteur (couple `Blade`, `Radius`) est affiche par une
  sphere coloree sur la pale correspondante, au rayon indique :
  - **L = vert** (0, 204, 0)
  - **M = jaune** (255, 204, 0)
  - **H = rouge** (255, 0, 0)

- **Dock temporel** (`Sensor CSV Data`, en bas de la fenetre) :
  slider temporel (50 Hz), bouton Play/Pause, case d'affichage, legende des couleurs.

## Fichiers modifies / ajoutes

| Fichier | Modification |
|---|---|
| `src/QTurbine/SensorDataManager.h/.cpp` | Nouveau — parsing CSV, categories L/M/H |
| `src/QTurbine/SensorCsvDock.h/.cpp` | Nouveau — dock slider temporel + play/pause |
| `src/QTurbine/SensorBladeMarkers.h/.cpp` | Nouveau — rendu 3D des marqueurs colores |
| `src/QTurbine/QTurbineModule.h/.cpp` | dock + slots import/clear + appel du rendu |
| `src/QTurbine/QTurbineMenu.h/.cpp` | entrees de menu Import/Clear Sensor CSV |
| `qblade.pro` | nouveaux fichiers dans SOURCES/HEADERS |
| `qblade.qrc` | Nouveau — ressource Qt generee depuis `images/` |
| `samples/sensor/example_sensors.csv` | Nouveau — CSV d'exemple (3 pales A/B/C, 5 capteurs) |

## Compilation (Linux, Qt 5.15)

```bash
sudo apt install qtbase5-dev qt5-qmake libqt5opengl5-dev libglu1-mesa-dev \
                 libblas-dev liblapack-dev gfortran
cd <repo>
mkdir -p data/Binaries/unix data/ControllerFiles/unix data/ControllerFiles/ParameterFiles data/StructuralFiles
qmake qblade.pro
make -j$(nproc)
```

## Compilation (Windows, Qt 5.15 + MinGW)

1. Installer Qt 5.15 (MinGW 64-bit) depuis qt.io
2. Ouvrir `qblade.pro` dans Qt Creator, ou en ligne de commande :
   ```bat
   C:\Qt\5.15.2\mingw81_64\bin\qmake.exe qblade.pro
   mingw32-make -j8
   ```
3. L'executable `release\QBladeCE.exe` est produit (copier les DLL Qt a cote si besoin).

## Utilisation

1. Lancer QBladeCE, ouvrir un projet avec une turbine (3 pales).
2. `Turbine Definition > Import Data > Import Sensor CSV Data...` -> choisir un CSV.
3. Le dock `Sensor CSV Data` apparait en bas : slider ou Play pour animer.
4. Marqueurs vert/jaune/rouge sur les pales selon `MagZ_category`.

## Compilation sous Windows (MinGW - chemin supporte)

Les DLL fournies dans `libraries/libs_windows_64bit/` (QGLViewer2, libChronoEngine,
libclblast, OpenCL, ...) sont **compilees avec MinGW** : un link MSVC ne peut pas les
utiliser (mangling C++ incompatible, et aucun `.lib` n'est fourni). Le build Windows
supporte est donc **Qt 5.15.2 + MinGW 8.1.0 64 bit** (comme dans `CompileInfo.txt` upstream).

Installation du kit MinGW de Qt (si pas deja fait) :

```cmd
C:\Python314\python.exe -m pip install aqtinstall
C:\Python314\python.exe -m aqt install-qt windows desktop 5.15.2 mingw81_64 -O C:\Qt
```

puis, dans une fenetre **cmd.exe** (PAS Git Bash) :

```cmd
cd C:\Users\MorganCORLAY\qblade-work\qbladece_2
patches\sync-mingw.bat        (git fetch + reset --hard, aucun patch MSVC)
patches\compile-mingw.bat     (qmake mingw81_64 + mingw32-make -j + windeployqt)
```

L'executable est `release\QBladeCE.exe`. Le build copie automatiquement dans `release\` :
- les DLL du dossier `libraries/libs_windows_64bit/` (cible qmake `copydlls`),
- les DLL de `data/Binaries/win`, `data/ControllerFiles/win`, ... (cibles upstream),
- les DLL Qt via `windeployqt` + le runtime MinGW (libgcc/libstdc++/winpthread).

Pour nettoyer : `patches\compile-mingw.bat clean`

## Utilisation

1. Lancer `release\QBladeCE.exe`, ouvrir une turbine.
2. Menu `Turbine Definition > Import Data > Import Sensor CSV Data...`, choisir le CSV
   (exemple fourni : `samples/sensor/example_sensors.csv`).
3. Le dock `Sensor CSV Data` en bas permet de parcourir le temps (slider / Play) :
   les capteurs apparaissent sur les pales A/B/C aux rayons indiquees, colores selon
   `MagZ_category` (L=vert, M=jaune, H=rouge).
