tag="alb"
#./build-image.sh -s orders -t ${tag} --multi-arch
#./build-image.sh -s checkout -t ${tag}
# build all
# ./build-image.sh -t ${tag}
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 127214168935.dkr.ecr.us-west-2.amazonaws.com

images=("utils" "assets" "checkout" "orders" "cart" "catalog" "ui")
#images=("checkout")
for image in "${images[@]}"
do
    echo "$str"
	./build-image.sh -s ${image} -t ${tag}
    docker image tag retail-store-sample-${image}:${tag}  127214168935.dkr.ecr.us-west-2.amazonaws.com/retail-store-sample-${image}:${tag}
    docker push 127214168935.dkr.ecr.us-west-2.amazonaws.com/retail-store-sample-${image}:${tag}
done

# docker image tag retail-store-sample-orders:${tag}  127214168935.dkr.ecr.us-west-2.amazonaws.com/retail-store-sample-orders:${tag}
# docker push 127214168935.dkr.ecr.us-west-2.amazonaws.com/retail-store-sample-orders:${tag}
