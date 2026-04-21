FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY ["ThreeW.Api/ThreeW.Api.csproj", "ThreeW.Api/"]
RUN dotnet restore "ThreeW.Api/ThreeW.Api.csproj"

COPY . .
RUN dotnet publish "ThreeW.Api/ThreeW.Api.csproj" \
    --configuration Release \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
EXPOSE 8080

COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "ThreeW.Api.dll"]