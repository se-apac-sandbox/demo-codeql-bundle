#!/bin/bash
set -e

CODEQL_BUNDLE_VERSION=$(gh release list --repo github/codeql-action -L 1 | awk '{split($0,a,"\t"); print a[3]}')
echo "[+] CodeQL Latest Bundle Release :: $CODEQL_BUNDLE_VERSION"

if [[ ! -f ./codeql-bundle.tar.gz ]]; then
  echo "[+] Downloading latest release of CodeQL"
  gh release --repo github/codeql-action download -p codeql-bundle.tar.gz $CODEQL_BUNDLE_VERSION
else
  echo "[+] Using cached archive"
fi

rm -rf ./codeql
tar -xvzf codeql-bundle.tar.gz

for ql_lang_path in queries/*; do
ql_lang=${ql_lang_path##*/}
qlquery_path=./codeql/qlpacks/codeql/$ql_lang-queries
qlquery_ver=$(ls $qlquery_path)
ghas_ql_path=$qlquery_path/$qlquery_ver/GHASfield
mkdir $ghas_ql_path
mv $ql_lang_path/* $ghas_ql_path/
done  

qlsuite_helper_ver=$(ls codeql/qlpacks/codeql/suite-helpers)
for suite_helper_file in suite-helpers/*; do
s_file=${suite_helper_file##*/} 
rm codeql/qlpacks/codeql/suite-helpers/$qlsuite_helper_ver/$s_file
mv suite-helpers/$s_file codeql/qlpacks/codeql/suite-helpers/$qlsuite_helper_ver/
done

for lang_pack_dir in codeql/qlpacks/codeql/*-queries; do
lang_dir=${lang_pack_dir##*/}
lang=${lang_dir%-queries}
echo "::warning::$lang"
using_packs=1
if [ -d codeql/qlpacks/codeql-$lang-lib ]; then
    echo "::warning::checkpoint1"
    qllib_path=codeql/qlpacks/codeql-$lang-lib
    qlquery_path=codeql/qlpacks/codeql-$lang
    #using_packs=0
else
    echo "::warning::checkpoint2"
    qllib_version=$(ls codeql/qlpacks/codeql/$lang-all)
    qllib_path=codeql/qlpacks/codeql/$lang-all/$qllib_version
    qlquery_version=$(ls codeql/qlpacks/codeql/$lang-queries)
    qlquery_path=codeql/qlpacks/codeql/$lang-queries/$qlquery_version
fi

if [ -d $qllib_path ]; then
    if [ -f $qllib_path/Customizations.qll -a -d customizations/$lang ]; then

        if [ ! -f $qllib_path/Customizations.qll ] && [ "$FORCE_CUSTOMIZATION" = "true" ]; then
            echo "::warning::Forcing customization for language $lang"
            echo "import $lang" > $qllib_path/Customizations.qll
            sed -i -e '0,/^import/s//private import Customizations\nimport/' $qllib_path/$lang.qll
        fi

        mkdir $qllib_path/customizations
        cp customizations/$lang/*.qll $qllib_path/customizations
        echo "::warning::checkpoint3"
        # Import custom modules
        for module_path in customizations/$lang/*.qll; do
            module_file=${module_path##*/}
            module_name=${module_file%.*}
            echo "import customizations.$module_name" >> $qllib_path/Customizations.qll
        done
    fi
    

    echo "Rebuilding pack at $qlquery_path"
    rm $qlquery_path/codeql-pack.lock.yml
    content_dir=/tmp/$lang
    pack_content=$content_dir/codeql/$lang-queries/$qlquery_version
    codeql/codeql pack create --additional-packs codeql/qlpacks/codeql/$lang-all:codeql/qlpacks/codeql/suite-helpers -j 0 --output=$content_dir $qlquery_path
    echo "Removing old pack content codeql/qlpacks/codeql/$lang-queries/$qlquery_version"
    rm -Rf codeql/qlpacks/codeql/$lang-queries/$qlquery_version
    echo "Moving pack content from '$pack_content' to codeql/qlpacks/codeql/$lang-queries"
    mv -v -f $pack_content codeql/qlpacks/codeql/$lang-queries/

        # echo "Rebuilding cache"
        # # Rebuild cache
        # rm -r $qlquery_path/.cache
        # codeql/codeql query compile --search-path codeql --threads 0 $qlquery_path

    else
    echo "::warning::Skipping customization for language $lang, because it doesn't have a Customizations.qll"
    fi

done

tar -czf codeql-bundle.tar.gz codeql
rm -r codeql

gh release create ${CODEQL_BUNDLE}-$(git rev-parse --short $GITHUB_SHA) codeql-bundle.tar.gz