FROM alpine:3.15 as build
RUN apk --update add ca-certificates
RUN echo "testy2:*:100:testy2" > /tmp/group && \
    echo "testy2:*:100:100::/:/testy2" > /tmp/passwd


FROM scratch

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /tmp/group \
    /tmp/passwd \
    /etc/
COPY testy2 /

USER testy2:testy2
EXPOSE 9219/tcp
ENTRYPOINT [ "/testy2" ]
