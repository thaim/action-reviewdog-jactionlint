#!/usr/bin/env bash

set -euo pipefail

if [ "${RUNNER_DEBUG:-}" = "1" ]; then
  set -x
fi

version="${INPUT_JACTIONLINT_VERSION}"
version="${version#v}"
if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::jactionlint_version must be an exact X.Y.Z version: '${version}'"
  exit 1
fi

case "$(uname -s)" in
  Linux) os=linux; ext=tar.gz ;;
  Darwin) os=darwin; ext=tar.gz ;;
  MINGW* | MSYS* | CYGWIN*) os=windows; ext=zip ;;
  *) echo "::error::unsupported OS: $(uname -s)"; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "::error::unsupported architecture: $(uname -m)"; exit 1 ;;
esac

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

echo "::group::Installing jactionlint v${version} ... https://github.com/jdx/jactionlint"
install_dir="$(mktemp -d)"
sarif="$(mktemp)"
trap 'rm -rf "${sarif}" "${install_dir}"' EXIT
archive="jactionlint_${version}_${os}_${arch}.${ext}"
checksums="jactionlint_${version}_checksums.txt"
base_url="https://github.com/jdx/jactionlint/releases/download/v${version}"
curl -fsSL -o "${install_dir}/${archive}" "${base_url}/${archive}"
curl -fsSL -o "${install_dir}/${checksums}" "${base_url}/${checksums}"

# The download script of jactionlint does not verify the archive, so check it against the checksums of the release here.
expected="$(awk -v f="${archive}" '$2 == f { print $1 }' "${install_dir}/${checksums}")"
actual="$(sha256 "${install_dir}/${archive}")"
if [ -z "${expected}" ] || [ "${expected}" != "${actual}" ]; then
  echo "::error::checksum mismatch for ${archive}: expected '${expected}', got '${actual}'"
  exit 1
fi

if [ "${ext}" = "zip" ]; then
  unzip -q -o "${install_dir}/${archive}" jactionlint.exe -d "${install_dir}"
  jactionlint="${install_dir}/jactionlint.exe"
else
  tar -xzf "${install_dir}/${archive}" -C "${install_dir}" jactionlint
  jactionlint="${install_dir}/jactionlint"
fi
"${jactionlint}" --version
echo '::endgroup::'

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}"

# Split the flags on whitespace without eval, so that an input cannot run commands through $(...) or backquotes.
read -r -a jactionlint_flags <<< "${INPUT_JACTIONLINT_FLAGS:-}"
read -r -a reviewdog_flags <<< "${INPUT_REVIEWDOG_FLAGS:-}"
if [ -n "${INPUT_PROFILE:-}" ]; then
  jactionlint_flags=(--profile "${INPUT_PROFILE}" ${jactionlint_flags[@]+"${jactionlint_flags[@]}"})
fi

echo '::group::Running jactionlint ...'
set +e
# The ${a[@]+...} form keeps an empty array from failing under set -u on bash 3.2, the /bin/bash of macOS.
"${jactionlint}" --format sarif ${jactionlint_flags[@]+"${jactionlint_flags[@]}"} > "${sarif}"
jactionlint_exit=$?
set -e

# Exit status 2 (invalid option) and 3 (fatal error) are failures of jactionlint itself, so do not hand them to reviewdog.
if [ "${jactionlint_exit}" -ge 2 ]; then
  cat "${sarif}"
  echo '::endgroup::'
  exit "${jactionlint_exit}"
fi

# Print the findings in the log too, because reviewdog only reports the lines that filter_mode lets through.
jq -r '.runs[].results[] | "\(.locations[0].physicalLocation.artifactLocation.uri):\(.locations[0].physicalLocation.region.startLine):\(.locations[0].physicalLocation.region.startColumn): \(.level): \(.message.text) [\(.ruleId)]"' "${sarif}"
echo '::endgroup::'

echo '::group::Running reviewdog ...'
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
reviewdog \
  -f=sarif \
  -name="${INPUT_TOOL_NAME}" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -fail-level="${INPUT_FAIL_LEVEL}" \
  -level="${INPUT_LEVEL}" \
  ${reviewdog_flags[@]+"${reviewdog_flags[@]}"} < "${sarif}"
echo '::endgroup::'
