FROM alpine:3.15 as build
RUN apk --update add ca-certificates
RUN cd /tmp/testy2 && \
    echo "testy2:*:100:testy2" > group && \
    echo "testy2:*:100:100::/:/testy2" > passwd


FROM scratch

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /tmp/testy2/group \
    /tmp/testy2/passwd \
    /etc/
COPY testy2 /

USER testy2:testy2
ENTRYPOINT [ "/testy2" ]
