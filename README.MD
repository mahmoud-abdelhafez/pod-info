- Install k8s on kind cluster
- install flux to reconcile the app repo to the cluster
- install flagger to manage the auto blue/green
- install the app pipeline for building new docker containers and push it to my repo using github actions
- On app change:
    - Github action will build a new docker image and push it to docker hub,
    - flux will watch the github repo and reconcile it on the cluster
    - Flagger will decide if the new deployment is health or not
    - based on the previous step the new release will be promoted to production or not
      Infra components
      Kind: lightweight kubernetes cluster that runs on docker
      Flux : is a gitops tool to reconcile your github repo on a kubernetes cluster
      Flagger: progressive k8s deployment software
      podinfo:  is our application that we want it to be deployed using the blue/green way

Infrastructure Provisioning:

We have to have a machine that have docker daemon already installed and runing
Our app is designed to run on a kubernetes cluster so we are going to install  a kind cluster (k8s on Docker)

Install kubectl
- on Linux
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```
Install kind:
- On Linux:
```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
mv ./kind /some-dir-in-your-PATH/kind
```

- On Mac
```
brew install kind
```

Create the k8s cluster:
```
cat > kind-config.yaml  <<EOF
# three node (two workers) cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

kind create cluster --name staging --config kind-config.yaml
```

Installing Flux  CLI

```
curl -s https://fluxcd.io/install.sh | sudo bash
flux check --pre
```

once all of the above tools are already installed,
We should  be  ready to bootstrap flux on our k8s cluster , After the bootstrap flux should reconcile the k8s resources on the k8s cluster
Before we run the bootstrap command we should generate a github token,

```
GitHub > Settings >  Developer settings > Personal access tokens > generate new token
Or login to your account and use the following URL
https://github.com/settings/tokens/new
```

Flux Bootstrapping
```
export GITHUB_TOKEN=YOUR-GENERATED-TOKEN
export GITHUB_USER=YOUR-USER-NAME

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=eks-new \
  --branch=main \
  --path=./clusters/kind-staging \
  --personal
```

- Once The bootstrap process completed, All application (Flagger, podinfo, test-pd) should be installed automatically

```
kubectl get pods -A |grep -e flagger -e test

:OutPut

flagger              flagger-6645456684-ghh4b                        1/1     Running   0          3h50m
flagger              flagger-prometheus-596d6965cb-glqwr             1/1     Running   0          3h50m
test                 podinfo-primary-7c9987b69d-gdpxk                1/1     Running   0          135m
test                 podinfo-primary-7c9987b69d-m6gtp                1/1     Running   0          135m
test                 test-pd                                         1/1     Running   0          3h34m
```

- To introduce a new app version
    - Change the version number that the build process reference
    
```
Go to the 3rd line on the following file: 
pod-info/pkg/version/version.go
var VERSION = "6.0.1"
```

- Then go to Gitghub app repo under
	- tags > Releases > Draft A new release > Tag Version <The new Version> Then publish a new release 
		- https://github.com/mahmoud-abdelhafez/pod-info/releases/new
- The above step will kick a new Github action release and will push a new image to dockerHub 
	- https://hub.docker.com/repository/docker/mahmoud3050/podinfo
- Once the new docker image is published, go to the following file and change the image tag to use the new version
	- Note: create a PR and merge it to the master 
	- https://github.com/mahmoud-abdelhafez/pod-info/blob/1f4cbbed0fa59252f0b947844f54f8c6f41ccf36/apps/staging/podinfo/deployment.yaml#L28

```
image: mahmoud3050/podinfo:4.0.1
```

- Once you merge the above change you should start see new pods are being created

```
kubectl get pods -n test 

podinfo-565cc5469c-8k6vl           1/1     Running   0          2m50s
podinfo-565cc5469c-nvjtn           1/1     Running   0          2m52s
podinfo-primary-76598f769d-mcntx   1/1     Running   0          30m
podinfo-primary-76598f769d-zxw4p   1/1     Running   0          30m
```
- The above Pods podinfo-565cc5469c-8k6vl & podinfo-565cc5469c-nvjtn  will be evaluated and checked if the are healthy enough to be promoted to server 100% of the traffic
- If succeeded You will see podinfo-primary-*  are being replaced by new pods which is the new app version
- To verify that your new version has really pushed to the podinfo-primary execute the following command
```
kubectl exec test-pd -n test -- curl podinfo-primary:9898

{
  "hostname": "podinfo-primary-8fd4b85f4-tx7vf",
  "version": "6.0.0",
  "revision": "",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "greetings from podinfo v6.0.0",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.16.5",
  "num_goroutine": "9",
  "num_cpu": "4"
}
```

Now it is the time to test introducing bad app version
- Create a new release using the previews steps of changing the application version under this file pod-info/pkg/version/version.go and push a new app release
- Change the current deployment image to the new image version image: mahmoud3050/podinfo:4.0.1 Under the following file.
    - https://github.com/mahmoud-abdelhafez/pod-info/blob/1f4cbbed0fa59252f0b947844f54f8c6f41ccf36/apps/staging/podinfo/deployment.yaml#L28
- Then go to the following line
    - Change  --random-error=false  to --random-error=true  in the following line:
        - https://github.com/mahmoud-abdelhafez/pod-info/blob/1f4cbbed0fa59252f0b947844f54f8c6f41ccf36/apps/staging/podinfo/deployment.yaml#L48
- Create a new PR and merge it to the master.
- The new release should be evaluated and would not make it to the production, you can run the following command to see that it is actually being tested
```
kubectl exec test-pd -n test -- curl podinfo-canary:9898
```

References:

REF:
https://docs.flagger.app/tutorials/kubernetes-blue-green
https://github.com/stefanprodan/podinfo
https://fluxcd.io/
