#!/usr/bin/env bash
#Author : Manjesh.munegowda@sap.com
#Purpose: Increment the image-version in Azure, for image push to image-defination
#
#Note   : Parameter1 will accept 3 options based on Azure versioning of the image
#         options are, -major, -minor, -patch
#         Example: if version (Parameter2) is 1.2.3 and -major is used, the new version will be 2.0.0
#                                                       -minor is used, the new version will be 1.3.0
#                                                       -patch is used, the new version will be 1.2.4

prg=$(basename $0)

[[ "$#" -lt "2" ]] && printf "Usage: $prg <option> <versionNumber> \n \t\tOption: -major | -minor | -patch\n\t\tversionNumber: 1.2.3\n" && exit 1

case $1 in
        -major)
                incNumber=`echo $2|awk -F. '{print $1}'`
                let "incNumber++"
                echo $2|awk  -F. -v nver="${incNumber}" -v OFS=. '{ $1=nver; print $1".0.0" }'
                ;;
        -minor)
                incNumber=`echo $2|awk -F. '{print $2}'`
                let "incNumber++"
                echo $2|awk  -F. -v nver="${incNumber}" -v OFS=. '{ $2=nver; print $1"."$2".0" }'
                ;;
        -patch)
                incNumber=`echo $2|awk -F. '{print $3}'`
                patch=$2
                let "incNumber++"
                echo $patch|awk  -F. -v nver="${incNumber}" -v OFS=. '{ $3=nver; print $0 }'
                ;;
        *)
                echo "Usage: $prg <option> <versionNumber>
                      Option       : -major | -minor | -patch
                      versionNumber: 1.2.3
                     "
                ;;
esac

