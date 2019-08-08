# This Dockerfile represents a multistage build. The stages, respectively:
#
# 1. build kubefed binaries
# 2. copy binaries

# build stage 1: build kubefed binaries
FROM openshift/origin-release:golang-1.12 as builder
RUN yum update -y
RUN yum install -y make git

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

WORKDIR /go/src/sigs.k8s.io/kubefed


COPY Makefile Makefile
COPY pkg pkg
COPY cmd cmd
COPY test test
COPY vendor vendor

RUN [ -z "$SOURCE_GIT_COMMIT" ] && DOCKER_BUILD="/bin/sh -c " make hyperfed || DOCKER_BUILD="/bin/sh -c " GIT_VERSION="$BUILD_VERSION" GIT_TAG="$SOURCE_GIT_TAG" GIT_HASH="$SOURCE_GIT_COMMIT" make hyperfed

# build stage 2:
FROM registry.svc.ci.openshift.org/openshift/origin-v4.0:base

ENV USER_ID=1001

# copy in binaries
RUN mkdir -p /hyperfed
RUN groupadd -r hyperfed
RUN useradd -g hyperfed -u $USER_ID hyperfed

WORKDIR /hyperfed/

# image builder is treating wild-carded source of the COPY command as a list
# and therefore treating the target as a dir. this gets us to having a single file
# called hyperfed in hyperfed directory.

COPY --from=builder /go/src/sigs.k8s.io/kubefed/bin/hyperfed-* /hyperfed/
RUN mv /hyperfed/hyperfed-* /hyperfed/hyperfed
RUN ln -s hyperfed controller-manager && ln -s hyperfed kubefedctl &&  ln -s hyperfed webhook

RUN chown -R hyperfed:hyperfed /hyperfed

# user directive - this image does not require root
USER hyperfed

ENTRYPOINT ["/hyperfed/controller-manager"]

# apply labels to final image
LABEL io.k8s.display-name="OpenShift KubeFed" \
      io.k8s.description="This is a component that allows management of Kubernetes/OpenShift resources across multiple clusters" \
maintainer="AOS Multicluster Team <aos-multicluster@redhat.com>"
