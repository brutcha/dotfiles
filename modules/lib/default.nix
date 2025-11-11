{ lib }:

{
  colors = {
    toARGB = hex: alpha: let
      cleanHex = lib.removePrefix "#" hex;
      alpha255 = builtins.floor (alpha * 255);
      alphaHex = lib.toHexString alpha255;
      paddedAlpha = if alpha255 < 16 then "0${alphaHex}" else alphaHex;
    in "0x${paddedAlpha}${cleanHex}";
  };
}
