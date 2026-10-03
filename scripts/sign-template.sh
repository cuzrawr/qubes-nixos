if [[ $# != 3 || ! $1 =~ ^[[:xdigit:]]{40,64}$ ]]; then
  echo "Usage: sign-template KEY_FINGERPRINT UNSIGNED_RPM SIGNED_RPM" >&2
  exit 2
fi
: "${GNUPGHOME:?Set GNUPGHOME to a dedicated template-signing keyring.}"
if [[ $GNUPGHOME != /* || ! -d $GNUPGHOME ]]; then
  echo "GNUPGHOME must be an existing absolute directory outside the repository." >&2
  exit 1
fi
key=$1
input=$2
output=$3
if [[ ! -f $input || -e $output ]]; then
  echo "Input must exist and output must be a new file." >&2
  exit 1
fi
temporary=$(mktemp --tmpdir="$(dirname -- "$output")" .qubes-template.XXXXXXXX.rpm)
trap 'rm -f -- "$temporary"' EXIT
cp -- "$input" "$temporary"
chmod u+w "$temporary"
rpmsign --define "_gpg_name $key" --define '_gpg_digest_algo sha256' --addsign "$temporary"
mv -T --update=none-fail -- "$temporary" "$output"
trap - EXIT
echo "Signed template: $output"
