{ lib, utils, ... }:

{
  config = {
    lib.colors = utils.colors;
  };
}
