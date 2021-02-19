FROM golang:1.15-buster as build

WORKDIR /go/src/app
ADD . /go/src/app

RUN go build -o /go/bin/app 



# multi-stage build example

FROM gcr.io/distroless/base-debian10:nonroot
COPY --from=build /go/bin/app /go/bin/app
USER nonroot

CMD ["/go/bin/app"]