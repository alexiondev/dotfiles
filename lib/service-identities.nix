{ lib }:
let
  defaultIdentities = {
    actualbudget = 20001;
    copyparty = 20002;
  };

  duplicateUidMessage = duplicates: ''
    Duplicate stable service UID allocation(s): ${lib.concatStringsSep ", " (
      map (entry: "${toString entry.uid} is assigned to ${lib.concatStringsSep ", " entry.names}") duplicates
    )}
  '';

  mk = identities:
    let
      names = lib.attrNames identities;
      namesByUid = lib.foldl' (
        acc: name:
        let
          uid = toString identities.${name};
        in
        acc // {
          ${uid} = (acc.${uid} or [ ]) ++ [ name ];
        }
      ) { } names;
      duplicates = lib.mapAttrsToList (uid: namesForUid: {
        uid = lib.toInt uid;
        names = namesForUid;
      }) (lib.filterAttrs (_uid: namesForUid: builtins.length namesForUid > 1) namesByUid);
      checkedIdentities =
        assert lib.assertMsg (duplicates == [ ]) (duplicateUidMessage duplicates);
        identities;
    in
    rec {
      inherit checkedIdentities;

      serviceUid = name:
        if builtins.hasAttr name checkedIdentities then
          checkedIdentities.${name}
        else
          throw "Unknown stable service identity `${name}`. Known identities: ${lib.concatStringsSep ", " (lib.attrNames checkedIdentities)}";
    };

  default = mk defaultIdentities;

  tests = {
    actualbudgetUid = default.serviceUid "actualbudget" == 20001;
    copypartyUid = default.serviceUid "copyparty" == 20002;
    missingLookupFails = !(builtins.tryEval (default.serviceUid "missing-service")).success;
    duplicateUidFails = !(builtins.tryEval (mk {
      first = 20003;
      second = 20003;
    }).checkedIdentities).success;
  };
in
default // {
  identities = default.checkedIdentities;
  inherit tests;
}
