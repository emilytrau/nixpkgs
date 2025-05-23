{
  lib,
  stdenv,
  fetchFromGitHub,
  python3Packages,
  buildNpmPackage,
  frida-tools,
  litecli,
}:

let
  version = "1.11.0-unstable-2025-05-10";
  src = fetchFromGitHub {
    owner = "sensepost";
    repo = "objection";
    rev = "a9e216c47c629c3836e7e447af6c2ad33d77132b";
    hash = "sha256-b1G4TEU57AWLcCqqg3Y1BhjbduFpAfHYj2m5ifiEhHc=";
  };

  objection-agent = buildNpmPackage {
    pname = "objection-agent";
    inherit version src;

    sourceRoot = "${src.name}/agent";

    preBuild = ''
      mkdir $out
      substituteInPlace package.json --replace-fail "../objection/agent.js" "$out/agent.js"
    '';

    npmDepsHash = "sha256-f9b7QPNNyWLk396rIIRn7jbb2ftX4vZMFqGP/TPN20E=";
  };
in
python3Packages.buildPythonApplication rec {
  pname = "objection";
  pyproject = true;
  inherit version src;

  preBuild = ''
    cp ${objection-agent}/agent.js objection/agent.js
  '';

  build-system = [
    python3Packages.setuptools
  ];

  dependencies = [
    python3Packages.frida-python
    frida-tools
    python3Packages.prompt-toolkit
    python3Packages.click
    python3Packages.tabulate
    python3Packages.semver
    python3Packages.delegator-py
    python3Packages.requests
    python3Packages.flask
    python3Packages.pygments
    litecli
    python3Packages.setuptools
  ];

  pythonRelaxDeps = [
    "semver"
  ];

  pythonImportsCheck = [
    "objection"
  ];

  meta = {
    description = "Instrumented Mobile Pentest Framework";
    homepage = "https://github.com/sensepost/objection";
    license = lib.licenses.gpl3Only;
    mainProgram = "objection";
    maintainers = with lib.maintainers; [ emilytrau ];
  };
}
