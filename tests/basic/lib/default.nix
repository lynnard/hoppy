{ stdenv, cppop, cppop-tests-basic-generator }:

let gen = cppop-tests-basic-generator;
    name = "cppop-tests-basic";
    libName = "lib${name}.so";
in

stdenv.mkDerivation {
  name = "${name}-lib-0.1.0";
  src = ./.;
  buildInputs = [ gen ];

  # Keep the -I... in sync with Makefile.
  prePatch = ''
    ${gen}/bin/generator --gen-cpp .
    substituteInPlace Makefile \
        --replace -I../../../cppop/include "-I${cppop}/include"
  '';

  installPhase = ''
    mkdir -p $out/lib
    install ${libName} $out/lib/${libName}.0.1.0
    cd $out/lib
    ln -s ${libName}.0.1{.0,}
    ln -s ${libName}.0{.1,}
    ln -s ${libName}{.0,}
  '';
}