{
  lib,
  stdenv,
  fetchurl,
  versionCheckHook,
  makeBinaryWrapper,
  libpcap,
  pkg-config,
  openssl,
  lua5_4,
  pcre2,
  liblinear,
  libssh2,
  zlib,
  python3,
  python3Packages,
  wrapGAppsHook3,
  writeDarwinBundle,
  withLua ? true,
  graphicalSupport ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "nmap";
  version = "7.97";

  src = fetchurl {
    url = "https://nmap.org/dist/nmap-${finalAttrs.version}.tar.bz2";
    hash = "sha256-r5jyeSXGcMJX3Zap3fJyTgbLebL9Hg0IySBjFr4WRcA=";
  };

  postPatch = ''
    substituteInPlace libz/configure \
        --replace-fail /usr/bin/libtool ar \
        --replace-fail 'AR="libtool"' 'AR="ar"' \
        --replace-fail 'ARFLAGS="-o"' 'ARFLAGS="-r"'
    substituteInPlace zenmap/zenmapCore/Paths.py \
        --replace-fail "/usr/local/bin" "$out/bin"
  '';

  patches = [
    # Fix python install prefix
    ./zenmap-python-env.patch
  ];

  configureFlags = [
    (if withLua then "--with-liblua=${lua5_4}" else "--without-liblua")
    (lib.withFeature graphicalSupport "zenmap")
  ];

  postInstall = ''
    install -m 444 -D nselib/data/passwords.lst $out/share/wordlists/nmap.lst
  '';

  preFixup =
    ''
      buildPythonPath "$out $propagatedBuildInputs"
      wrapProgram $out/bin/ndiff \
        --prefix PYTHONPATH : "$program_PYTHONPATH"
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      install_name_tool -change liblinear.so.5 ${liblinear.out}/lib/liblinear.5.dylib $out/bin/nmap
    ''
    + lib.optionalString graphicalSupport ''
      wrapProgram $out/bin/zenmap \
        --prefix PYTHONPATH : "$program_PYTHONPATH" \
        --prefix GTK_PATH : "$out/lib/gtk-2.0" \
        "''${gappsWrapperArgs[@]}"
      install -m 444 -D zenmap/zenmapCore/data/pixmaps/zenmap.png $out/share/pixmaps/zenmap.png
    ''
    + lib.optionalString (graphicalSupport && stdenv.hostPlatform.isDarwin) ''
      mkdir -p "$out/Applications/Zenmap.app/Contents/MacOS"
      mkdir -p "$out/Applications/Zenmap.app/Contents/Resources"
      cp zenmap/install_scripts/macosx/zenmap.icns "$out/Applications/Zenmap.app/Contents/Resources/zenmap.icns"
      write-darwin-bundle "$out" "Zenmap" "zenmap" "zenmap" "false"
      mv "$out/Applications/Zenmap.app/Contents/MacOS/Zenmap" "$out/Applications/Zenmap.app/Contents/MacOS/zenmap.bin"
      ${stdenv.cc.targetPrefix}cc "zenmap/install_scripts/macosx/zenmap_auth.m" -lobjc -framework Foundation -o "$out/Applications/Zenmap.app/Contents/MacOS/Zenmap"
    '';

  dontWrapGApps = true;

  makeFlags = lib.optionals (stdenv.buildPlatform != stdenv.hostPlatform) [
    "AR=${stdenv.cc.bintools.targetPrefix}ar"
    "RANLIB=${stdenv.cc.bintools.targetPrefix}ranlib"
    "CC=${stdenv.cc.targetPrefix}gcc"
  ];

  nativeBuildInputs =
    [
      pkg-config
      python3
      python3Packages.wrapPython
      python3Packages.build
      python3Packages.pip
      python3Packages.setuptools
      makeBinaryWrapper
    ]
    ++ lib.optionals graphicalSupport [
      wrapGAppsHook3
    ]
    ++ lib.optionals (graphicalSupport && stdenv.hostPlatform.isDarwin) [
      writeDarwinBundle
    ];
  buildInputs = [
    pcre2
    liblinear
    libssh2
    libpcap
    openssl
    zlib
  ];
  propagatedBuildInputs = lib.optionals graphicalSupport [
    python3Packages.pygobject3
  ];

  enableParallelBuilding = true;

  doCheck = false; # fails 3 tests, probably needs the net

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = "-V";
  doInstallCheck = true;

  meta = {
    description = "Free and open source utility for network discovery and security auditing";
    homepage = "http://www.nmap.org";
    changelog = "https://nmap.org/changelog.html#${finalAttrs.version}";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;
    mainProgrem = "nmap";
    maintainers = with lib.maintainers; [
      thoughtpolice
      fpletz
    ];
  };
})
