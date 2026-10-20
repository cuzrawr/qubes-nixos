if [[ $# != 3 || ! $1 =~ ^[[:xdigit:]]{40,64}$ ]]; then
  echo "usage: sign-template KEY_FINGERPRINT UNSIGNED_RPM SIGNED_RPM" >&2
  exit 2
fi
: "${GNUPGHOME:?set GNUPGHOME to a dedicated template-signing keyring.}"
if [[ $GNUPGHOME != /* || ! -d $GNUPGHOME ]]; then
  echo "GNUPGHOME must be an existing absolute directory." >&2
  exit 1
fi
key=$1
input=$2
output=$3
if [[ ! -f $input || -e $output ]]; then
  echo "input must exist and output must be a new file." >&2
  exit 1
fi
temporary=$(mktemp --tmpdir="$(dirname -- "$output")" .qubes-template.XXXXXXXX.rpm)
trap 'rm -f -- "$temporary"' EXIT
cp -- "$input" "$temporary"
chmod u+w "$temporary"
rpmsign --rcfile "$QUBES_NIXOS_RPM_CONFIG/rpmrc" --macros "$QUBES_NIXOS_RPM_CONFIG/macros" \
  --define '_gpg_path %{getenv:GNUPGHOME}' \
  --define "_gpg_name $key" --define '_gpg_digest_algo sha256' --addsign "$temporary"
mv -T --update=none-fail -- "$temporary" "$output"
trap - EXIT
echo "signed template: $output"
