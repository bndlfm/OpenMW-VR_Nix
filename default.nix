{ pkgs
, lib
, stdenv

, cmake
, pkg-config
, python3

, fetchFromGitLab
, fetchFromGitHub

### DOCUMENTATION
, doxygen
, graphviz # Doxygen requires dot

### LIBRARIES
, boost
, bullet
, ffmpeg_6 # Please unpin this on the next OpenMW release.
, libGL
, libglvnd
, libuuid
, luajit
, lz4
, mesa
, mygui
, nvidia_x11
, openal
, openscenegraph
, openxr-loader
, recastnavigation
, SDL2
, unshield
, wrapQtAppsHook
, yaml-cpp

### MAC OS SPECIFIC
, CoreMedia
, VideoToolbox
, VideoDecodeAcceleration

### LINUX (XORG) SPECIFIC?
, xorg

}:

let

  bullet' = bullet.overrideDerivation (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-Wno-dev"
      "-DOpenGL_GL_PREFERENCE=${GL}"
      "-DUSE_DOUBLE_PRECISION=ON"
      "-DBULLET2_MULTITHREADING=ON"
    ];
  });

  GL = "GLVND"; # or "LEGACY";

  mkDerivation = pkgs.libsForQt5.callPackage ({ mkDerivation }: mkDerivation) {};

  openxr-sdk = fetchFromGitHub {
    owner = "bndlfm";
    repo = "OpenXR-SDK_4_OpenMW-VR_Nix";
    rev = "d417ad122a04c1a6d191928170aa1a6368229678";
    hash = "sha256-5tbOsvMWVvWZUl48QtqBJhVqpUMk3WzDY5lhxXx7l0w=";
  };

in

  mkDerivation {
    pname = "openmw_vr";
    version = "0.48.0";

    src = fetchFromGitLab {
      owner = "madsbuvi";
      repo = "openmw";
      rev = "770584c5112e46be1a00b9e357b0b7f6b449cac5";
      hash = "sha256-C8lFjKIdbHyvRcZzJNUj8Lif9IqNvuYURwRMpb4sxiQ=";
    };

    postPatch = /*sh*/ ''
      sed '1i#include <memory>' -i components/myguiplatform/myguidatamanager.cpp ### gcc12
    '' + lib.optionalString stdenv.hostPlatform.isDarwin /* sh */ ''
      sed -i '/fixup_bundle/d' CMakeLists.txt ### Don't fix Darwin app bundle
    '';

    # If not set, OSG plugin .so files become shell scripts on Darwin.
    dontWrapQtApps = stdenv.hostPlatform.isDarwin;

    buildInputs = [
      boost
      bullet'
      doxygen
      ffmpeg_6
      graphviz
      libglvnd
      luajit
      lz4
      mesa
      mygui
      openal
      openscenegraph
      openxr-loader
      recastnavigation
      SDL2
      unshield
      yaml-cpp
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
      CoreMedia
      VideoDecodeAcceleration
      VideoToolbox
    ] ++ lib.optionals stdenv.hostPlatform.isLinux [
      xorg.libXdmcp
      xorg.libXrandr
      xorg.libXt
      xorg.libXxf86vm
    ];

    nativeBuildInputs = [
      cmake
      pkg-config
      python3
      wrapQtAppsHook
    ];

    runtimeDependencies = [
      libuuid
      libGL
      mesa
    ];

    enableParallelBuilding = true;

    cmakeFlags = [
      "-DOpenGL_GL_PREFERENCE=LEGACY"
      "-DOPENMW_USE_SYSTEM_RECASTNAVIGATION=1"
      "-DFETCHCONTENT_SOURCE_DIR_OPENXR=${openxr-sdk}"
      "-DBUILD_OPENMW_VR=ON"
      "-DCMAKE_BUILD_TYPE=RELEASE"
      "-DCMAKE_SKIP_BUILD_PATH=ON"
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
      "-DOPENMW_OSX_DEPLOYMENT=ON"
    ];

    installPhase = /*sh*/ ''
      runHook preInstall

      # Run the default install phase provided by CMake
      cmake --build . --target install

      mkdir -p "$out/bin"

      # Copy the openmw_vr binary to the output directory.
      install -m755 ./openmw_vr $out/bin

      runHook postInstall
    '';

    #postFixup = /*sh*/ ''
    #  omwvrExe="$out/bin/openmw_vr"
    #  origRpath="$(patchelf --print-rpath "$omwvrExe")"
    #  patchelf --set-rpath "${lib.makeLibraryPath [ libGL libglvnd libuuid ]}:$origRpath" "$omwvrExe"
    #  '';

    doCheck = false;
    doInstallCheck = false;
    dontCheck = true;

    meta = with lib; {
      description = "Unofficial VR open source engine reimplementation of the game Morrowind";
      homepage = "https://openmw.org";
      license = licenses.gpl3Plus;
      maintainers = with maintainers; [ ];
      platforms = platforms.linux ++ platforms.darwin;
    };
  }

