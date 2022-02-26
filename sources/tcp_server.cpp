#define WIN32_LEAN_AND_MEAN
#include <iostream>
#include <cstdio>
#include <stdio.h>
#include <string.h>
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdlib.h>
#include <stdio.h>
#pragma comment (lib, "Ws2_32.lib")
#pragma comment (lib, "Mswsock.lib")
#pragma comment (lib, "AdvApi32.lib")
using namespace std;
int i_error = 0;
int main(void)
{
    //0. настройка библиотеки Ws2_32.dll
    WSADATA wsaData;//определяем переменную
    i_error = WSAStartup(MAKEWORD(2, 2), &wsaData);//настраиваем
    if (i_error)
    {
        printf("ERROR!\n");
    }
    else
    {
        printf("Biblioteka uspehno sozdana!\n");
    }
    int socket_desc, client_sock, client_size;
    struct sockaddr_in server_addr {}, client_addr {};
    char client_message [2000];

    // очистить буфер:
    memset(client_message, '\0', sizeof(client_message));

    // создать сокет:
    socket_desc = socket(AF_INET, SOCK_STREAM, 0);

    if (socket_desc < 0) {
        printf("Error while creating socket\n");
        return -1;
    }
    printf("Socket created successfully\n");

    // Set port and IP:
    inet_pton(AF_INET, "127.0.0.1", &server_addr.sin_addr.s_addr);
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(2000);


    // забиндить порт и IP:
    if (bind(socket_desc, (SOCKADDR*) &server_addr, sizeof(server_addr)) < 0) {
        printf("Couldn't bind to the port\n");
        return -1;
    }
    printf("Done with binding\n");

    // прослушивание клиентов:
    if (listen(socket_desc, 1) < 0) {
        printf("Error while listening\n");
        return -1;
    }
    printf("\nListening for incoming connections.....\n");

    // Принять входящее соединение :
    client_size = sizeof(client_addr);
    client_sock = accept(socket_desc, (SOCKADDR*) &client_addr, &client_size);

    if (client_sock < 0) {
        printf("Can't accept\n");
        return -1;
    }
    printf("Client connected at IP: %s and port: %s\n", ntohs(client_addr.sin_port));

    // приять сообщение от клиента:
    if (recv(client_sock, client_message, sizeof(client_message), 0) < 0) {
        printf("Couldn't receive\n");
        return -1;
    }
    printf("Msg from client: %s\n", client_message);


    // закрыть сокеты:
    closesocket(client_sock);
    closesocket(socket_desc);

    return 0;
}
