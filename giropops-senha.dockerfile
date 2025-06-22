FROM cgr.dev/chainguard/python:latest-dev AS dev
WORKDIR /app
RUN python -m venv venv
ENV PATH="/app/venv/bin":$PATH
COPY requirements.txt .
COPY app.py .
COPY templates templates/
COPY static static/
RUN pip install --no-cache-dir -r requirements.txt

FROM cgr.dev/chainguard/python:latest
WORKDIR /app
COPY --from=dev /app .
ENV PATH="/app/venv/bin:$PATH"
EXPOSE 5000
ENTRYPOINT ["python"]
CMD ["-m", "flask", "run", "--host=0.0.0.0"]
