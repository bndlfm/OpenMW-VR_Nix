{ pkgs, lib }:
let
  bullet' = pkgs.bullet.overrideDerivation (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-Wno-dev"
      "-DOpenGL_GL_PREFERENCE=${GL}"
      "-DUSE_DOUBLE_PRECISION=ON"
      "-DBULLET2_MULTITHREADING=ON"
    ];
  });

  GL = "GLVND"; # or "LEGACY";

  qtMkDerivation = pkgs.libsForQt5.callPackage ({ mkDerivation }: mkDerivation) {};

  openxr-sdk = pkgs.stdenv.mkDerivation {
    pname = "openxr-sdk";
    version = "1.1.43";
    src = pkgs.fetchFromGitHub {
      owner = "KhronosGroup";
      repo = "OpenXR-SDK";
      rev = "b7ada0bdecd9830f27c2221dad6f0bb933c64f15";
      hash = "sha256-YsT6z0uymEF35US1ux7E4JOAK6YeOzryulYVGRi0EjA=";
    };
    patches = [
      ./openxr.pc.in.patch
    ];
    dontBuild = true;
  };



  #openxr-sdk = fetchFromGitHub {
  #  owner = "bndlfm";
  #  repo = "OpenXR-SDK_4_OpenMW-VR_Nix";
  #  rev = "d417ad122a04c1a6d191928170aa1a6368229678";
  #  hash = "sha256-5tbOsvMWVvWZUl48QtqBJhVqpUMk3WzDY5lhxXx7l0w=";
  #};

in

  qtMkDerivation {
    pname = "openmw_vr";
    version = "0.48.0";

    src = pkgs.fetchFromGitLab {
      owner = "madsbuvi";
      repo = "openmw";
      rev = "770584c5112e46be1a00b9e357b0b7f6b449cac5";
      hash = "sha256-C8lFjKIdbHyvRcZzJNUj8Lif9IqNvuYURwRMpb4sxiQ=";
    };

    postPatch = /*sh*/ ''
      sed '1i#include <memory>' -i components/myguiplatform/myguidatamanager.cpp ### gcc12
    ''
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin /*sh*/ ''
      ### DON'T FIX DARWIN APP BUNDLE
      sed -i '/fixup_bundle/d' CMakeLists.txt
    '';

    buildInputs = with pkgs; [
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

    nativeBuildInputs = with pkgs; [
      cmake
      pkg-config
      python3
      pkgs.libsForQt5.wrapQtAppsHook
    ];


    #preBuild = /*sh*/ ''
      ### COPY BROKEN PC.IN TO BUILD DIRECTORY
       # echo "Making ${sdkBldPath}"
       # mkdir -p ${sdkBldPath}

       # echo "Copying openxr-sdk git source to ${sdkBldPath}"
       # cp -v "${openxr-sdk}" "${sdkBldPath}"

       # ### PATCH $NIX_BUILD_TOP/openxr-sdk/src/loader/openxr.pc.in TO REMOVE ''${exec_prefix}/@CMAKE_INSTALL_LIBDIR TO @CMAKE_INSTALL_FULL_LIBDIR
       # echo "Patching ${sdkBldPath}/src/loader/openxr.pc.in"
       # sed -i 's|libdir=\''${exec_prefix}/@CMAKE_INSTALL_LIBDIR@|libdir=@CMAKE_INSTALL_FULL_LIBDIR@|' ${sdkBldPath}/src/loader/openxr.pc.in
    #'';

    enableParallelBuilding = true;

    cmakeFlags = [
      "-DOpenGL_GL_PREFERENCE=LEGACY"
      "-DOPENMW_USE_SYSTEM_RECASTNAVIGATION=1"
      "-DFETCHCONTENT_SOURCE_DIR_OPENXR=${openxr-sdk}"
      "-DCMAKE_SKIP_BUILD_RPATH=ON"
      "-DBUILD_OPENMW_VR=ON"
      "-DCMAKE_BUILD_TYPE=RELEASE"
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      "-DOPENMW_OSX_DEPLOYMENT=ON"
    ];

    # If not set, OSG plugin .so files become shell scripts on Darwin.
    dontWrapQtApps = pkgs.stdenv.hostPlatform.isDarwin;

    runtimeDependencies = with pkgs; [
      libuuid
      libGL
      mesa
    ];

    installPhase = /*sh*/ ''
      runHook preInstall

      ### Run the default install phase provided by CMake
      cmake --build . --target install


      ### Think the dir is already made by cmake?
      #mkdir -p "$out/bin"
      ### Copy the openmw_vr binary to the output directory.
      install -m755 ./openmw_vr $out/bin

      runHook postInstall
    '';

    #postFixup = /*sh*/ ''
    #  omwvrExe="$out/bin/openmw_vr"
    #  origRpath="$(patchelf --print-rpath "$omwvrExe")"
    #  patchelf --set-rpath "${lib.makeLibraryPath [ libGL libglvnd libuuid ]}:$origRpath" "$omwvrExe"
    #  '';

    meta = with lib; {
      description = "Unofficial VR open source engine reimplementation of the game Morrowind";
      homepage = "https://openmw.org";
      license = licenses.gpl3Plus;
      maintainers = with maintainers; [ ];
      platforms = platforms.linux ++ platforms.darwin;
    };
  }

