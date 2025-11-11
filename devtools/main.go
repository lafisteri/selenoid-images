package main

import (
	"fmt"
	"net/http"
)

func main() {
	// Ничего не делаем — бинарь просто существует в системе, как и было.
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "devtools stub")
	})
	// Не слушаем порт по умолчанию, чтобы ничего не мешало; просто завершаемся.
}
