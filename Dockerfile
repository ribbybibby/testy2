FROM golang:1.17-alpine AS build

ADD . /tmp/testy2

RUN cd /tmp/testy2 && \
    echo "testy2:*:100:testy2" > group && \
    echo "testy2:*:100:100::/:/testy2" > passwd && \
    make


FROM scratch

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /tmp/testy2/group \
    /tmp/testy2/passwd \
    /etc/
COPY --from=build /tmp/testy2/testy2_exporter /

USER testy2:testy2
EXPOSE 9219/tcp
ENTRYPOINT ["/testy2"]
